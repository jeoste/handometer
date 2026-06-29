import AppKit
import UniformTypeIdentifiers

/// Export des statistiques vers CSV ou JSON via un panneau d'enregistrement.
enum Exporter {
    static func exportJSON(days: [String: DayStats]) {
        let panel = savePanel(suggestedName: "macbook-stats.json", type: .json)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(days)
            try data.write(to: url, options: .atomic)
        } catch {
            present(error)
        }
    }

    static func exportCSV(days: [String: DayStats]) {
        let panel = savePanel(suggestedName: "macbook-stats.csv", type: .commaSeparatedText)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sorted = days.values.sorted { $0.date < $1.date }
        // Colonnes de touches = union de toutes les touches rencontrées, triées.
        let allKeys = Set(sorted.flatMap { $0.keyCounts.keys }).sorted()

        var rows: [String] = []
        rows.append((["date", "distance_cm"] + allKeys).map(csvEscape).joined(separator: ","))
        for day in sorted {
            var cells = [day.date, String(format: "%.2f", day.mouseDistanceCm)]
            cells += allKeys.map { String(day.keyCounts[$0] ?? 0) }
            rows.append(cells.map(csvEscape).joined(separator: ","))
        }

        do {
            try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            present(error)
        }
    }

    // MARK: - Helpers

    private static func savePanel(suggestedName: String, type: UTType) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        return panel
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
