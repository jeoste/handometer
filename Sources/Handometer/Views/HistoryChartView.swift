import SwiftUI
import Charts

/// Graphiques d'historique : distance souris et frappes par jour.
struct HistoryChartView: View {
    let history: [DayStats]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if history.isEmpty {
                    Text("Pas encore d'historique. Reviens demain !")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    section(title: "Distance souris par jour (cm)") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Jour", day.date),
                                y: .value("cm", day.mouseDistanceCm)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 220)
                    }

                    section(title: "Frappes clavier par jour") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Jour", day.date),
                                y: .value("Frappes", day.totalKeystrokes)
                            )
                            .foregroundStyle(.green)
                        }
                        .frame(height: 220)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}
