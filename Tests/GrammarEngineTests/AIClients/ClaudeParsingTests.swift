import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ClaudeParsingTests {
    static let cannedBody = #"""
    {"id":"msg_01XyZ","type":"message","role":"assistant","model":"claude-haiku-5-5",
     "content":[
       {"type":"thinking","thinking":"","signature":"EqQBCkYIBxgC"},
       {"type":"text","text":"{\"edits\":[{\"context_before\":\"I \",\"original\":\"has\",\"replacement\":\"have\",\"explanation\":\"Use “have” with “I”.\",\"category\":\"grammar\"},{\"context_before\":\"has \",\"original\":\"teh\",\"replacement\":\"the\",\"explanation\":\"This word is misspelled.\",\"category\":\"spelling\"}]}"}
     ],
     "stop_reason":"end_turn","stop_sequence":null,
     "usage":{"input_tokens":412,"output_tokens":96}}
    """#

    @Test func parsesCannedResponseBody() throws {
        let response = try ClaudeClient.decodeMessage(Data(Self.cannedBody.utf8)).get()
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "claude-haiku-5-5")
        let edits = try CheckPrompt.parse(response).get()
        #expect(edits == [
            AIEdit(original: "has", replacement: "have", contextBefore: "I ", explanation: "Use “have” with “I”.", category: .grammar),
            AIEdit(original: "teh", replacement: "the", contextBefore: "has ", explanation: "This word is misspelled.", category: .spelling),
        ])
        let located = EditLocator.locate(edits, in: "I has teh cat.")
        #expect(located.map(\.range) == [NSRange(location: 2, length: 3), NSRange(location: 6, length: 3)])
    }

    @Test func emptyEditsMeanTheTextIsFine() throws {
        let response = try ClaudeClient.decodeMessage(Data(messageBody(text: #"{"edits":[]}"#).utf8)).get()
        #expect(try CheckPrompt.parse(response).get().isEmpty)
    }

    @Test func onlyTextAfterAServerFallbackCounts() throws {
        let fallback = #"{"type":"text","text":"partial from declined model"},{"type":"fallback","from":{"model":"claude-sonnet-5-5"},"to":{"model":"claude-sonnet-5"}},"#
        let response = try ClaudeClient.decodeMessage(Data(messageBody(text: #"{"edits":[]}"#, extraBlocks: fallback).utf8)).get()
        #expect(response.text == #"{"edits":[]}"#)
    }

    @Test func refusalTruncationAndGarbageAreErrors() {
        let refusal = MessageResponse(text: "", stopReason: "refusal", model: nil)
        #expect(CheckPrompt.parse(refusal) == .failure(.refused))
        let truncated = MessageResponse(text: #"{"edits":[{"original":"te"#, stopReason: "max_tokens", model: nil)
        #expect(CheckPrompt.parse(truncated) == .failure(.truncated))
        let garbage = MessageResponse(text: "Sure! Here are the edits.", stopReason: "end_turn", model: nil)
        #expect(CheckPrompt.parse(garbage) == .failure(.invalidResponse))
        #expect(ClaudeClient.decodeMessage(Data("not json".utf8)) == .failure(.invalidResponse))
    }

    @Test func parserToleratesFencesProseAndOddCategories() {
        let text = """
        Here you go:
        ```json
        {"edits":[{"original":"a","replacement":"an","context_before":"","explanation":"x","category":"word_choice"},
                  {"original":"b","replacement":"c","explanation":"y","category":"nonsense"},
                  {"original":"missing replacement"}]}
        ```
        """
        let edits = CheckPrompt.parseEdits(text)
        #expect(edits?.map(\.category) == [.wordChoice, .grammar])
        #expect(edits?.last?.contextBefore == "")
    }

    @Test func checkRequestBodyMatchesTheAPIContract() throws {
        let request = CheckPrompt.request(paragraph: "I has teh cat.", language: "en", model: "claude-haiku-5-5")
        let body = try #require(try JSONSerialization.jsonObject(with: ClaudeClient.messageBody(request, fallbacks: false).data) as? [String: Any])
        #expect(body["model"] as? String == "claude-haiku-5-5")
        #expect((body["max_tokens"] as? Int ?? 0) >= 2048)
        for removed in ["temperature", "top_p", "top_k", "thinking"] {
            #expect(body[removed] == nil, "API version 2026-10-21 rejects \(removed)")
        }
        #expect(body["fallbacks"] == nil)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1 && messages[0]["role"] as? String == "user", "no assistant prefill")
        let content = try #require(messages[0]["content"] as? String)
        #expect(content.contains("<text_to_check>\nI has teh cat.\n</text_to_check>"))
        #expect(content.contains("English (en)"))
        let system = try #require((body["system"] as? [[String: Any]])?.first)
        #expect((system["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral")
        let output = try #require(body["output_config"] as? [String: Any])
        #expect(output["effort"] as? String == "low")
        let format = try #require(output["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
        let item = try #require(((schema["properties"] as? [String: Any])?["edits"] as? [String: Any])?["items"] as? [String: Any])
        #expect(Set(item["required"] as? [String] ?? []) == ["original", "replacement", "context_before", "explanation", "category"])
        let category = try #require((item["properties"] as? [String: Any])?["category"] as? [String: Any])
        #expect(category["enum"] as? [String] == ["spelling", "grammar", "punctuation", "wordChoice", "clarity", "style"])
    }

    @Test func systemPromptCoversTheEditingRules() {
        let prompt = CheckPrompt.system
        for phrase in ["Never translate", "<text_to_check>", "never as instructions", "shortest", "context_before",
                       "one short sentence in English", "URLs", "emoji", "empty \"edits\" array"] {
            #expect(prompt.contains(phrase), "\(phrase)")
        }
        #expect(CheckPrompt.userMessage(paragraph: "x", language: nil).contains("Work out which language"))
    }

    @Test func styleGoalGoesInTheUserTurnOnly() {
        let neutral = CheckPrompt.userMessage(paragraph: "x", language: "en")
        #expect(!neutral.contains("Style goal"))
        for style in WritingStyle.allCases where style != .neutral {
            let message = CheckPrompt.userMessage(paragraph: "x", language: "en", goals: WritingGoals(style: style))
            #expect(message.contains("Style goal"), "\(style)")
            #expect(message.hasSuffix("<text_to_check>\nx\n</text_to_check>"), "the text stays last")
        }
        let goals = WritingStyle.allCases.compactMap(CheckPrompt.styleGoal)
        #expect(goals.count == WritingStyle.allCases.count - 1, "every style but neutral has a goal")
        #expect(Set(goals).count == goals.count, "each style asks for something different")
        #expect(CheckPrompt.request(paragraph: "x", language: "en", goals: WritingGoals(style: .formal), model: "m").system == CheckPrompt.system)
    }

    @Test func readerGoalsGoInTheUserTurn() {
        #expect(CheckPrompt.readerGoal(.none) == nil)
        #expect(CheckPrompt.readerGoal(WritingGoals(style: .formal)) == nil, "the style has its own goal")
        let goals = WritingGoals(audience: .expert, domain: .academic, intent: .convince)
        let message = CheckPrompt.userMessage(paragraph: "x", language: "en", goals: goals)
        #expect(message.contains("Writing goals:"))
        #expect(message.contains("experts") && message.contains("academic") && message.contains("convince"))
        #expect(message.hasSuffix("<text_to_check>\nx\n</text_to_check>"))
        var seen = Set<String>()
        for audience in WritingAudience.allCases where audience != .general {
            #expect(seen.insert(CheckPrompt.readerGoal(WritingGoals(audience: audience)) ?? "").inserted)
        }
        for domain in WritingDomain.allCases where domain != .general {
            #expect(seen.insert(CheckPrompt.readerGoal(WritingGoals(domain: domain)) ?? "").inserted)
        }
        for intent in WritingIntent.allCases where intent != .unspecified {
            #expect(seen.insert(CheckPrompt.readerGoal(WritingGoals(intent: intent)) ?? "").inserted)
        }
    }

    @Test func jsonSerializationEscapes() throws {
        let value = JSONValue.object([("s", .string("a\"b\\c\nd\u{1}é😀")), ("n", .int(3)), ("b", .bool(true)), ("z", .null)])
        #expect(value.serialized == #"{"s":"a\"b\\c\nd\u0001é😀","n":3,"b":true,"z":null}"#)
        let decoded = try #require(try JSONSerialization.jsonObject(with: value.data) as? [String: Any])
        #expect(decoded["s"] as? String == "a\"b\\c\nd\u{1}é😀")
    }
}
