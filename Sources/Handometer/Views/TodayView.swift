import SwiftUI

/// Résumé des statistiques du jour : distance souris et total de frappes,
/// plus le détail des touches les plus fréquentes.
struct TodayView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    StatCard(
                        title: "Distance souris",
                        value: Self.formatDistance(state.today.mouseDistanceCm),
                        systemImage: "cursorarrow.motionlines"
                    )
                    StatCard(
                        title: "Frappes clavier",
                        value: "\(state.today.totalKeystrokes)",
                        systemImage: "keyboard"
                    )
                }

                Text("Touches du jour")
                    .font(.headline)

                if state.today.keyCounts.isEmpty {
                    Text("Aucune frappe enregistrée aujourd'hui.")
                        .foregroundStyle(.secondary)
                } else {
                    KeyFrequencyView(keyCounts: state.today.keyCounts)
                }
            }
            .padding()
        }
    }

    static func formatDistance(_ cm: Double) -> String {
        if cm >= 100 {
            return String(format: "%.2f m", cm / 100)
        }
        return String(format: "%.1f cm", cm)
    }
}

/// Petite carte de statistique mise en valeur.
struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
