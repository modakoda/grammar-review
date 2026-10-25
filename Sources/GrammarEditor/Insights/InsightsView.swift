import GrammarEngine
import GrammarModels
import GrammarOverlay
import SwiftUI

struct InsightsView: View {
    let model: EditorModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ToneSection(model: model)
                ReadabilitySection(model: model)
                CountsSection(statistics: model.statistics)
            }
            .padding(12)
        }
    }
}
