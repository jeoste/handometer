import Foundation

enum AchievementEvaluator {
    static func evaluate(
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int],
        alreadyUnlocked: [UnlockedAchievement],
        currentDayKey: String,
        includeDaily: Bool = true
    ) -> [UnlockedAchievement] {
        let existingKeys = Set(alreadyUnlocked.map(\.uniquenessKey))
        var results: [UnlockedAchievement] = []

        let scopes: [AchievementScope] = includeDaily ? [.daily, .allTime] : [.allTime]

        for scope in scopes {
            for kind in AchievementKind.allCases {
                let definition = AchievementDefinition(kind: kind, scope: scope)
                let uniquenessKey: String
                if scope == .daily {
                    uniquenessKey = "\(kind.rawValue)_\(scope.rawValue)_\(currentDayKey)"
                } else {
                    uniquenessKey = "\(kind.rawValue)_\(scope.rawValue)"
                }
                guard !existingKeys.contains(uniquenessKey) else { continue }
                guard !results.contains(where: { $0.uniquenessKey == uniquenessKey }) else { continue }

                if let unlock = check(
                    definition: definition,
                    today: today,
                    history: history,
                    globalKeyCounts: globalKeyCounts,
                    currentDayKey: currentDayKey
                ) {
                    results.append(unlock)
                }
            }
        }

        return results
    }

    private static func check(
        definition: AchievementDefinition,
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int],
        currentDayKey: String
    ) -> UnlockedAchievement? {
        switch definition.kind {
        case .key100, .key500:
            let minCount = Int(definition.threshold)
            let counts = definition.scope == .daily ? today.keyCounts : globalKeyCounts
            guard let top = topKey(in: counts, min: minCount) else { return nil }
            return UnlockedAchievement(
                kind: definition.kind,
                scope: definition.scope,
                dayKey: definition.scope == .daily ? currentDayKey : nil,
                contextKey: top.key,
                contextValue: Double(top.count)
            )

        case .mouse1km:
            let distance: Double
            if definition.scope == .daily {
                distance = today.mouseDistanceCm
            } else {
                distance = totalMouseDistanceCm(in: history)
            }
            guard distance >= definition.threshold else { return nil }
            return UnlockedAchievement(
                kind: definition.kind,
                scope: definition.scope,
                dayKey: definition.scope == .daily ? currentDayKey : nil,
                contextKey: nil,
                contextValue: distance
            )
        }
    }

    static func topKey(in counts: [String: Int], min: Int) -> (key: String, count: Int)? {
        guard let best = counts.max(by: { $0.value < $1.value }), best.value >= min else {
            return nil
        }
        return (best.key, best.value)
    }

    static func totalMouseDistanceCm(in history: [DayStats]) -> Double {
        history.reduce(0) { $0 + $1.mouseDistanceCm }
    }

    /// Progression vers le prochain seuil (0…1) pour l'affichage des cartes verrouillées.
    static func progress(
        for definition: AchievementDefinition,
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int]
    ) -> Double {
        let threshold = definition.threshold
        let current: Double

        switch definition.kind {
        case .key100, .key500:
            let counts = definition.scope == .daily ? today.keyCounts : globalKeyCounts
            current = Double(counts.values.max() ?? 0)
        case .mouse1km:
            current = definition.scope == .daily
                ? today.mouseDistanceCm
                : totalMouseDistanceCm(in: history)
        }

        guard threshold > 0 else { return 0 }
        return min(current / threshold, 1)
    }
}
