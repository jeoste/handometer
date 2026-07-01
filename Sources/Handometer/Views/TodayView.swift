import SwiftUI

/// Résumé des statistiques du jour : distance souris, vitesse, clics et total
/// de frappes, plus le détail des touches les plus fréquentes.
struct TodayView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var units = UnitPreferences.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, spacing: 16) {
                    StatCard(
                        title: "Mouse distance",
                        value: units.formatDistance(cm: state.today.mouseDistanceCm),
                        systemImage: "cursorarrow.motionlines"
                    )
                    StatCard(
                        title: "Keystrokes today",
                        value: "\(state.today.totalKeystrokes)",
                        systemImage: "keyboard",
                        subtitle: "All time: \(state.totalKeystrokes)"
                    )
                    StatCard(
                        title: "Average speed",
                        value: units.formatSpeed(kmh: state.today.averageSpeedKmh),
                        systemImage: "gauge.with.dots.needle.50percent"
                    )
                    StatCard(
                        title: "Max speed",
                        value: units.formatSpeed(kmh: state.today.maxSpeedKmh),
                        systemImage: "speedometer"
                    )
                    StatCard(
                        title: "Clicks",
                        value: "\(state.today.totalClicks)",
                        systemImage: "cursorarrow.click",
                        subtitle: "L \(state.today.leftClicks) · R \(state.today.rightClicks) · M \(state.today.middleClicks)"
                    )
                }

                Text("Today's keys")
                    .font(.headline)

                if state.today.keyCounts.isEmpty {
                    Text("No keystrokes recorded today.")
                        .foregroundStyle(.secondary)
                } else {
                    KeyFrequencyView(keyCounts: state.today.keyCounts)
                }

                if !state.globalKeyCounts.isEmpty {
                    Text("All-time keys")
                        .font(.headline)
                        .padding(.top, 4)

                    KeyFrequencyView(keyCounts: state.globalKeyCounts)
                }
            }
            .padding()
        }
    }

}

/// Petite carte de statistique mise en valeur.
struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
