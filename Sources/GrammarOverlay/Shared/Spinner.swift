import SwiftUI

package struct Spinner: View {
    var size: CGFloat = 12
    var lineWidth: CGFloat = 1.5
    var color: Color = .secondary
    var arc: CGFloat = 0.7

    package init(size: CGFloat = 12, lineWidth: CGFloat = 1.5, color: Color = .secondary, arc: CGFloat = 0.7) {
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.arc = arc
    }

    package var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let turns = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            Circle()
                .trim(from: 0, to: arc)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(turns * 360))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Checking")
    }
}
