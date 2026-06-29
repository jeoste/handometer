import SwiftUI
import Charts

/// Graphiques d'historique : distance souris, vitesses, clics et frappes par jour.
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
                    section(title: "All-time keystrokes") {
                        HStack(spacing: 16) {
                            Label("Total", systemImage: "keyboard")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(history.totalKeystrokes)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(history.count) day\(history.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

                        if !history.aggregatedKeyCounts.isEmpty {
                            Text("Most used keys (all time)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            KeyFrequencyView(keyCounts: history.aggregatedKeyCounts)
                        }
                    }

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

                    section(title: "Average speed per day (km/h)") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value("km/h", day.averageSpeedKmh)
                            )
                            .foregroundStyle(.teal)
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
