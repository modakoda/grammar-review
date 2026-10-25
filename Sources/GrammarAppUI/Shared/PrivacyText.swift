import Foundation

enum PrivacyText {
    static let summary = """
    Text is read only from the field you're typing in, never from password fields or disabled apps. \
    Spelling, and English grammar when Harper is installed, are checked on this Mac. When AI \
    suggestions are on, the field's text (up to your character limit) is sent after you pause typing: \
    to the AI service you chose (Anthropic, OpenAI, xAI, Google, Mistral or DeepSeek) with your own \
    API key, or to the local model server you set up. The editor's plagiarism check sends sentences to \
    Brave Search only when you click Check. Only settings and request counts are saved to disk, never \
    your text.
    """
}
