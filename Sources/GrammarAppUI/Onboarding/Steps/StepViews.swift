import SwiftUI

struct StepDots: View {
    let current: OnboardingModel.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingModel.Step.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current.rawValue + 1) of \(OnboardingModel.Step.allCases.count)")
    }
}

struct StepHeader: View {
    let symbol: String
    let title: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44)
            Text(title)
                .font(.title2.bold())
        }
        .padding(.bottom, 14)
    }
}

struct Bullet: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
