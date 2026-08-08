import Foundation

/// Persistance des achievements débloqués dans
/// `~/Library/Application Support/Handometer/achievements.json`.
///
/// Même règle que `StatsStore` : l'état vit sur le main actor, seule l'écriture
/// disque part sur la file, à partir d'un snapshot.
@MainActor
final class AchievementStore {
    private let fileURL: URL
    private static let ioQueue = DispatchQueue(label: "com.jeoste.handometer.achievements")
    private var saveWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 5

    private(set) var unlocks: [UnlockedAchievement] = []
    /// Cache incrémental des clés d'unicité (évite de reconstruire un Set
    /// depuis la liste — qui grossit sans borne — à chaque évaluation).
    private(set) var unlockedKeys: Set<String> = []

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handometer", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("achievements.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([UnlockedAchievement].self, from: data) {
            unlocks = decoded
            unlockedKeys = Set(decoded.map(\.uniquenessKey))
        }
    }

    func scheduleSave() {
        guard saveWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveDebounced() }
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Chemin débouncé : snapshot sur le main actor, écriture sur la file d'I/O.
    private func saveDebounced() {
        saveWorkItem = nil
        let snapshot = unlocks
        let url = fileURL
        Self.ioQueue.async { Self.write(snapshot, to: url) }
    }

    /// Écriture immédiate **et synchrone** (arrêt de l'app).
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        Self.write(unlocks, to: fileURL)
    }

    private nonisolated static func write(_ unlocks: [UnlockedAchievement], to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(unlocks)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Handometer: achievement save failed — \(error)")
        }
    }

    /// Ajoute les nouveaux unlocks (ignore les doublons) et retourne ceux réellement ajoutés.
    @discardableResult
    func add(_ newUnlocks: [UnlockedAchievement], dayKey: String) -> [UnlockedAchievement] {
        guard !newUnlocks.isEmpty else { return [] }
        var added: [UnlockedAchievement] = []

        for unlock in newUnlocks {
            let key = unlock.uniquenessKey
            guard !unlockedKeys.contains(key) else { continue }
            unlocks.append(unlock)
            unlockedKeys.insert(key)
            added.append(unlock)
        }

        if !added.isEmpty {
            scheduleSave()
        }
        return added
    }

    /// Scan rétroactif des all-time achievements (sans notification).
    @discardableResult
    func retroactiveScan(context: MetricContext) -> [UnlockedAchievement] {
        let newUnlocks = AchievementEvaluator.evaluate(
            context: context,
            alreadyUnlockedKeys: unlockedKeys,
            includeDaily: false
        )
        return add(newUnlocks, dayKey: context.currentDayKey)
    }

    func unlocks(for scope: AchievementScope, dayKey: String) -> [UnlockedAchievement] {
        unlocks.filter { unlock in
            guard unlock.scope == scope else { return false }
            if scope == .daily {
                return unlock.dayKey == dayKey
            }
            return true
        }
    }
}
