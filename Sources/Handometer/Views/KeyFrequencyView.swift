import SwiftUI
import Charts

/// Diagramme à barres horizontales des touches les plus fréquentes.
struct KeyFrequencyView: View {
    let keyCounts: [String: Int]
    var maxItems: Int = 20

    private var topKeys: [(key: String, count: Int)] {
        keyCounts
            .sorted { $0.value > $1.value }
            .prefix(maxItems)
            .map { (key: $0.key, count: $0.value) }
    }

    var body: some View {
        Chart(topKeys, id: \.key) { item in
            BarMark(
                x: .value("Keystrokes", item.count),
                y: .value("Key", item.key)
            )
            .annotation(position: .trailing) {
                Text("\(item.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .frame(height: CGFloat(max(topKeys.count, 1) * 28 + 20))
    }
}
