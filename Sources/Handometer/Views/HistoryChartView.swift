import SwiftUI
import Charts

/// Graphiques d'historique : distance souris, vitesses, clics et frappes par jour.
struct HistoryChartView: View {
    let history: [DayStats]
    @ObservedObject private var units = UnitPreferences.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if history.isEmpty {
                    Text("No history yet. Come back tomorrow!")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    UnitsPickerBar()

                    section(title: "Daily breakdown") {
                        ForEach(history.reversed(), id: \.date) { day in
                            DayHistoryRow(day: day)
                        }
                    }

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

                    section(title: units.chartDistanceSectionTitle) {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value(units.chartDistanceLabel, units.chartDistanceValue(cm: day.mouseDistanceCm))
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(units.formatChartDistanceAxis(v))
                                    }
                                }
                            }
                        }
                        .id(units.distanceUnit)
                        .frame(height: 220)
                    }

                    section(title: "Average speed per day (\(units.chartSpeedLabel))") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value(units.chartSpeedLabel, units.chartSpeedValue(kmh: day.averageSpeedKmh))
                            )
                            .foregroundStyle(.teal)
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text("\(units.formatChartSpeedAxis(v)) \(units.chartSpeedLabel)")
                                    }
                                }
                            }
                        }
                        .id(units.speedUnit)
                        .frame(height: 220)
                    }

                    section(title: "Max speed per day (\(units.chartSpeedLabel))") {
                        Chart(history, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date),
                                y: .value(units.chartSpeedLabel, units.chartSpeedValue(kmh: day.maxSpeedKmh))
                            )
                            .foregroundStyle(.orange)
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text("\(units.formatChartSpeedAxis(v)) \(units.chartSpeedLabel)")
                                    }
                                }
                            }
                        }
                        .id(units.speedUnit)
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

/// Détail des statistiques pour une journée passée.
private struct DayHistoryRow: View {
    let day: DayStats
    @ObservedObject private var units = UnitPreferences.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var formattedDate: String {
        guard let date = DateFormatter.dayKey.date(from: day.date) else { return day.date }
        return DateFormatter.dayDisplay.string(from: date)
    }

    var body: some View {
        DisclosureGroup {
            if day.keyCounts.isEmpty {
                Text("No keystrokes recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                KeyFrequencyView(keyCounts: day.keyCounts, maxItems: 12)
                    .padding(.top, 4)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(formattedDate)
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: columns, spacing: 10) {
                    dayStat(
                        title: "Distance",
                        value: units.formatDistance(cm: day.mouseDistanceCm),
                        systemImage: "cursorarrow.motionlines"
                    )
                    dayStat(
                        title: "Keystrokes",
                        value: "\(day.totalKeystrokes)",
                        systemImage: "keyboard"
                    )
                    dayStat(
                        title: "Avg speed",
                        value: units.formatSpeed(kmh: day.averageSpeedKmh),
                        systemImage: "gauge.with.dots.needle.50percent"
                    )
                    dayStat(
                        title: "Max speed",
                        value: units.formatSpeed(kmh: day.maxSpeedKmh),
                        systemImage: "speedometer"
                    )
                    dayStat(
                        title: "Clicks",
                        value: "\(day.totalClicks)",
                        systemImage: "cursorarrow.click",
                        subtitle: "L \(day.leftClicks) · R \(day.rightClicks) · M \(day.middleClicks)"
                    )
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dayStat(title: String, value: String, systemImage: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
