import SwiftUI
import Charts

/// Métrique affichée dans le graphique d'évolution de l'historique.
private enum HistoryMetric: String, CaseIterable, Identifiable {
    case distance
    case keystrokes
    case clicks
    case averageSpeed
    case maxSpeed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance:     return "Distance"
        case .keystrokes:   return "Keys"
        case .clicks:       return "Clicks"
        case .averageSpeed: return "Avg"
        case .maxSpeed:     return "Max"
        }
    }

    var systemImage: String {
        switch self {
        case .distance:     return "cursorarrow.motionlines"
        case .keystrokes:   return "keyboard"
        case .clicks:       return "cursorarrow.click"
        case .averageSpeed: return "gauge.with.dots.needle.50percent"
        case .maxSpeed:     return "speedometer"
        }
    }

    var color: Color {
        switch self {
        case .distance:     return .blue
        case .keystrokes:   return .green
        case .clicks:       return .purple
        case .averageSpeed: return .teal
        case .maxSpeed:     return .orange
        }
    }

    func chartValue(for day: DayStats, units: UnitPreferences) -> Double {
        switch self {
        case .distance:
            return units.chartDistanceValue(cm: day.mouseDistanceCm)
        case .keystrokes:
            return Double(day.totalKeystrokes)
        case .clicks:
            return Double(day.totalClicks)
        case .averageSpeed:
            return units.chartSpeedValue(kmh: day.averageSpeedKmh)
        case .maxSpeed:
            return units.chartSpeedValue(kmh: day.maxSpeedKmh)
        }
    }

    func formatAxisValue(_ value: Double, units: UnitPreferences) -> String {
        switch self {
        case .distance:
            return units.formatChartDistanceAxis(value)
        case .keystrokes, .clicks:
            return units.formatChartCountAxis(value)
        case .averageSpeed, .maxSpeed:
            return "\(units.formatChartSpeedAxis(value)) \(units.chartSpeedLabel)"
        }
    }

    func formatBarValue(_ value: Double, units: UnitPreferences) -> String {
        switch self {
        case .distance:
            let cm: Double
            switch units.distanceUnit {
            case .meters: cm = value * 100
            case .steps:  cm = value * DistanceUnit.metersPerStep * 100
            }
            return units.formatDistance(cm: cm)
        case .keystrokes:
            return "\(Int(value)) keys"
        case .clicks:
            return "\(Int(value)) clicks"
        case .averageSpeed, .maxSpeed:
            let kmh = units.speedUnit == .mph ? value * 1.609344 : value
            return units.formatSpeed(kmh: kmh)
        }
    }

    /// Titre du graphique incluant l'unité courante.
    func chartTitle(units: UnitPreferences) -> String {
        switch self {
        case .distance:
            return units.chartDistanceSectionTitle
        case .keystrokes:
            return "Keystrokes per day"
        case .clicks:
            return "Clicks per day"
        case .averageSpeed:
            return "Average speed per day (\(units.chartSpeedLabel))"
        case .maxSpeed:
            return "Max speed per day (\(units.chartSpeedLabel))"
        }
    }

    /// Identifiant de rafraîchissement quand les unités changent.
    func unitsRefreshID(units: UnitPreferences) -> String {
        switch self {
        case .distance:
            return units.distanceUnit.rawValue
        case .averageSpeed, .maxSpeed:
            return units.speedUnit.rawValue
        case .keystrokes, .clicks:
            return "count"
        }
    }
}

/// Graphiques d'historique : résumé, tendance par métrique, détail jour par jour.
struct HistoryChartView: View {
    let history: [DayStats]
    /// Compteurs de touches cumulés (cache fourni par AppState, jamais
    /// recalculé ici pour éviter un merge complet à chaque render).
    let keyCounts: [String: Int]
    @ObservedObject private var units = UnitPreferences.shared
    @State private var selectedMetric: HistoryMetric = .keystrokes

    private let summaryColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if history.isEmpty {
                    Text("No history yet. Come back tomorrow!")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    UnitsPickerBar()

                    periodSummary

                    trendSection

                    if !keyCounts.isEmpty {
                        allTimeKeysSection
                    }

                    section(title: "Daily breakdown") {
                        ForEach(history.reversed(), id: \.date) { day in
                            DayHistoryRow(day: day)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Résumé de la période

    private var periodSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Period summary")
                .font(.headline)

            LazyVGrid(columns: summaryColumns, spacing: 12) {
                StatCard(
                    title: "Distance",
                    value: units.formatDistance(cm: history.totalMouseDistanceCm),
                    systemImage: "cursorarrow.motionlines",
                    subtitle: "\(history.count) day\(history.count == 1 ? "" : "s")"
                )
                StatCard(
                    title: "Keystrokes",
                    value: "\(history.totalKeystrokes)",
                    systemImage: "keyboard"
                )
                StatCard(
                    title: "Clicks",
                    value: "\(history.totalClicks)",
                    systemImage: "cursorarrow.click"
                )
                StatCard(
                    title: "Avg speed",
                    value: units.formatSpeed(kmh: history.averageDailySpeedKmh),
                    systemImage: "gauge.with.dots.needle.50percent"
                )
            }
        }
    }

    // MARK: - Graphique de tendance

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.headline)

            Picker("Metric", selection: $selectedMetric) {
                ForEach(HistoryMetric.allCases) { metric in
                    Text(metric.label).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Label(selectedMetric.chartTitle(units: units), systemImage: selectedMetric.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Chart(history, id: \.date) { day in
                    let value = selectedMetric.chartValue(for: day, units: units)
                    BarMark(
                        x: .value("Day", chartDate(from: day.date), unit: .day),
                        y: .value(selectedMetric.label, value)
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                    .cornerRadius(5)
                    .annotation(position: .top, spacing: 4) {
                        if history.count <= 14 {
                            Text(selectedMetric.formatBarValue(value, units: units))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(history.count, 7))) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(selectedMetric.formatAxisValue(v, units: units))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .chartPlotStyle { plot in
                    plot.padding(.horizontal, 4)
                }
                .id(selectedMetric.unitsRefreshID(units: units))
                .frame(height: 240)
            }
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Touches all-time

    private var allTimeKeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most used keys (all time)")
                .font(.headline)
            KeyFrequencyView(keyCounts: keyCounts)
        }
    }

    // MARK: - Helpers

    private func chartDate(from dayKey: String) -> Date {
        DateFormatter.dayKey.date(from: dayKey) ?? .distantPast
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}

// MARK: - Agrégats historiques

private extension Array where Element == DayStats {
    /// Vitesse moyenne quotidienne moyennée sur la période.
    var averageDailySpeedKmh: Double {
        guard !isEmpty else { return 0 }
        let total = reduce(0.0) { $0 + $1.averageSpeedKmh }
        return total / Double(count)
    }
}

// MARK: - Détail journalier

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
