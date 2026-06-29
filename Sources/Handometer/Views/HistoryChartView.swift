import SwiftUI
import Charts

/// Graphiques d'historique : distance souris, vitesse max, clics et frappes par jour.
struct HistoryChartView: View {
    let history: [DayStats]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if history.isEmpty {
                    Text("No history yet. Come back tomorrow!")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    section(title: "Mouse distance per day (cm)") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value("cm", day.mouseDistanceCm)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 220)
                    }

                    section(title: "Max speed per day (km/h)") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value("km/h", day.maxSpeedKmh)
                            )
                            .foregroundStyle(.orange)
                        }
                        .frame(height: 220)
                    }

                    section(title: "Clicks per day") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value("Clicks", day.totalClicks)
                            )
                            .foregroundStyle(.purple)
                        }
                        .frame(height: 220)
                    }

                    section(title: "Keystrokes per day") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value("Keystrokes", day.totalKeystrokes)
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
