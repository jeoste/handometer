import Foundation

/// Persistance des achievements débloqués dans
/// `~/Library/Application Support/Handometer/achievements.json`.
final class AchievementStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.jeoste.handometer.achievements")
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
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        let snapshot = unlocks
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Handometer: achievement save failed — \(error)")
        }
    }

    func isUnlocked(_ definition: AchievementDefinition, dayKey: String) -> Bool {
        unlockedKeys.contains(uniquenessKey(for: definition, dayKey: dayKey))
    }

    func uniquenessKey(for definition: AchievementDefinition, dayKey: String) -> String {
        if definition.scope == .daily {
            return "\(definition.kind.rawValue)_\(definition.scope.rawValue)_\(dayKey)"
        }
        return "\(definition.kind.rawValue)_\(definition.scope.rawValue)"
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
    func retroactiveScan(
        history: [DayStats],
        globalKeyCounts: [String: Int],
        currentDayKey: String
    ) -> [UnlockedAchievement] {
        let newUnlocks = AchievementEvaluator.evaluate(
            today: history.last(where: { $0.date == currentDayKey }) ?? DayStats(date: currentDayKey),
            history: history,
            globalKeyCounts: globalKeyCounts,
            alreadyUnlockedKeys: unlockedKeys,
            currentDayKey: currentDayKey,
            includeDaily: false
        )
        return add(newUnlocks, dayKey: currentDayKey)
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
