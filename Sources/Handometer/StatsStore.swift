import Foundation

/// Persistance des statistiques dans un fichier JSON, sous
/// `~/Library/Application Support/Handometer/stats.json`.
///
/// L'écriture est *débouncée* : les mutations rapides ne déclenchent qu'une
/// sauvegarde toutes les quelques secondes. Une sauvegarde immédiate est
/// disponible via `saveNow()` (à l'arrêt de l'app).
final class StatsStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.jeoste.macbookstats.store")
    private var saveWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 5

    /// Toutes les journées, indexées par clé `YYYY-MM-DD`.
    private(set) var days: [String: DayStats] = [:]

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handometer", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("stats.json")
        load()
    }

    /// URL du fichier de données (exposée pour le bouton « Révéler dans le Finder »).
    var storageURL: URL { fileURL }

    // MARK: - Lecture / écriture disque

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: DayStats].self, from: data) {
            days = decoded
        }
    }

    /// Planifie une sauvegarde débouncée.
    func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Écrit immédiatement sur le disque.
    func saveNow() {
        saveWorkItem?.cancel()
        let snapshot = days
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Handometer: échec de sauvegarde — \(error)")
        }
    }

    // MARK: - Mutations

    /// Récupère (ou crée) les stats d'un jour donné.
    func stats(for dayKey: String) -> DayStats {
        days[dayKey] ?? DayStats(date: dayKey)
    }

    /// Ajoute une distance (cm) au jour indiqué.
    func addDistance(_ cm: Double, to dayKey: String) {
        var d = stats(for: dayKey)
        d.mouseDistanceCm += cm
        days[dayKey] = d
    }

    /// Incrémente le compteur d'une touche pour le jour indiqué.
    func incrementKey(_ key: String, in dayKey: String) {
        var d = stats(for: dayKey)
        d.keyCounts[key, default: 0] += 1
        days[dayKey] = d
    }
}
