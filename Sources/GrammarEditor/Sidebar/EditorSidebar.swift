import GrammarModels
import GrammarOverlay
import SwiftUI

struct EditorSidebar: View {
    let model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: tabBinding) {
                ForEach(SidebarTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            switch model.sidebarTab {
            case .suggestions: suggestions
            case .insights: InsightsView(model: model)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabBinding: Binding<SidebarTab> {
        Binding(get: { model.sidebarTab }, set: { model.sidebarTab = $0 })
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if let session = model.compose {
                            ComposeCard(session: session, model: model)
                                .id(ComposeCard.scrollID)
                        }
                        if let session = model.rewrite {
                            RewriteCard(session: session, model: model)
                                .id(RewriteCard.scrollID)
                        }
                        ForEach(model.filteredIssues) { issue in
                            SuggestionCard(issue: issue, isExpanded: model.selectedIssueID == issue.id, model: model)
                                .id(issue.id)
                        }
                        if model.filteredIssues.isEmpty, model.rewrite == nil, model.compose == nil {
                            EmptyState(model: model)
                        }
                        if !model.ignoredIssues.isEmpty {
                            IgnoredList(issues: model.ignoredIssues) { model.restore($0) }
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                    .animation(.snappy(duration: 0.2), value: model.filteredIssues.map(\.id))
                    .animation(.snappy(duration: 0.2), value: model.ignoredIssues.map(\.fingerprint))
                    .animation(.snappy(duration: 0.2), value: model.selectedIssueID)
                }
                .onChange(of: model.selectedIssueID) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: model.rewrite?.id) { _, id in
                    guard id != nil else { return }
                    withAnimation(.snappy(duration: 0.2)) { proxy.scrollTo(RewriteCard.scrollID, anchor: .top) }
                }
                .onChange(of: model.compose?.id) { _, id in
                    guard id != nil else { return }
                    withAnimation(.snappy(duration: 0.2)) { proxy.scrollTo(ComposeCard.scrollID, anchor: .top) }
                }
            }
            if model.acceptAllCount > 1 {
                Divider()
                Button("Accept All \(model.acceptAllCount) Correctness Fixes") { model.acceptAll() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .padding(10)
            }
        }
    }

    private var goalsDescription: String {
        let goals = model.goals
        if goals == WritingGoals(style: goals.style) { return "\(goals.style.displayName): \(goals.style.detail)" }
        return "Goals: \(goals.summary)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(IssueSummary.title(forCount: model.count(of: nil)))
                    .font(.headline)
                Spacer(minLength: 4)
                if model.status == .checking {
                    Spinner(size: 11)
                    Text("Checking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                FilterChip(title: "All", count: model.count(of: nil), color: nil, isSelected: model.filter == nil) {
                    model.filter = nil
                }
                ForEach(IssueSeverity.allCases, id: \.self) { severity in
                    FilterChip(
                        title: severity.title,
                        count: model.count(of: severity),
                        color: severity.color,
                        isSelected: model.filter == severity
                    ) {
                        model.filter = model.filter == severity ? nil : severity
                    }
                }
            }
            if case .notice(let message, let offersSettings) = model.status {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(nsColor: .systemOrange))
                    Text(message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if offersSettings {
                        Button("Settings") { model.openSettings() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }
                .font(.system(size: 11))
            }
            if !model.goals.isNone {
                Label(goalsDescription, systemImage: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}
