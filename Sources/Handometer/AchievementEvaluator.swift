import Foundation

enum AchievementEvaluator {
    static func evaluate(
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int],
        alreadyUnlockedKeys existingKeys: Set<String>,
        currentDayKey: String,
        includeDaily: Bool = true
    ) -> [UnlockedAchievement] {
        var results: [UnlockedAchievement] = []

        let scopes: [AchievementScope] = includeDaily ? [.daily, .allTime] : [.allTime]

        for scope in scopes {
            for kind in AchievementKind.allCases {
                guard AchievementDefinition.applicableScopes(for: kind).contains(scope) else { continue }
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
        let (value, contextKey) = currentValue(
            for: definition,
            today: today,
            history: history,
            globalKeyCounts: globalKeyCounts,
            currentDayKey: currentDayKey
        )
        guard definition.threshold > 0, value >= definition.threshold else { return nil }

        return UnlockedAchievement(
            kind: definition.kind,
            scope: definition.scope,
            dayKey: definition.scope == .daily ? currentDayKey : nil,
            contextKey: contextKey,
            contextValue: value
        )
    }

    /// Valeur courante d'une métrique pour un scope donné, et clé de contexte
    /// éventuelle (ex. la touche la plus pressée). Source unique partagée par
    /// `check` (déblocage) et `progress` (affichage).
    static func currentValue(
        for definition: AchievementDefinition,
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int],
        currentDayKey: String
    ) -> (value: Double, contextKey: String?) {
        let daily = definition.scope == .daily

        switch definition.metric {
        case .topKeyCount:
            let counts = daily ? today.keyCounts : globalKeyCounts
            guard let best = counts.max(by: { $0.value < $1.value }) else { return (0, nil) }
            return (Double(best.value), best.key)

        case .totalKeystrokes:
            return (Double(daily ? today.totalKeystrokes : history.totalKeystrokes), nil)

        case .mouseDistanceCm:
            return (daily ? today.mouseDistanceCm : totalMouseDistanceCm(in: history), nil)

        case .totalClicks:
            return (Double(daily ? today.totalClicks : history.reduce(0) { $0 + $1.totalClicks }), nil)

        case .rightClicks:
            return (Double(daily ? today.rightClicks : history.reduce(0) { $0 + $1.rightClicks }), nil)

        case .middleClicks:
            return (Double(daily ? today.middleClicks : history.reduce(0) { $0 + $1.middleClicks }), nil)

        case .maxSpeedKmh:
            let value = daily ? today.maxSpeedKmh : (history.map(\.maxSpeedKmh).max() ?? 0)
            return (value, nil)

        case .streakDays:
            return (streakDays(history: history, currentDayKey: currentDayKey), nil)

        case .spaceKeys:
            return (keyCount(SpecialKey.space, daily: daily, today: today, globalKeyCounts: globalKeyCounts), nil)

        case .backspaceKeys:
            return (keyCount(SpecialKey.backspace, daily: daily, today: today, globalKeyCounts: globalKeyCounts), nil)

        case .escKeys:
            return (keyCount(SpecialKey.esc, daily: daily, today: today, globalKeyCounts: globalKeyCounts), nil)

        case .enterKeys:
            return (keyCount(SpecialKey.enter, daily: daily, today: today, globalKeyCounts: globalKeyCounts), nil)

        case .arrowKeys:
            let total = SpecialKey.arrows.reduce(0.0) {
                $0 + keyCount($1, daily: daily, today: today, globalKeyCounts: globalKeyCounts)
            }
            return (total, nil)

        case .uniqueKeys:
            return (Double(today.keyCounts.count), nil)

        case .movementSeconds:
            return (daily ? today.movementSeconds : history.reduce(0) { $0 + $1.movementSeconds }, nil)
        }
    }

    /// Libellés produits par `EventMonitor.label(for:)` pour les touches spéciales.
    private enum SpecialKey {
        static let space = "⎵ Space"
        static let backspace = "⌫ Backspace"
        static let esc = "⎋ Esc"
        static let enter = "↩ Enter"
        static let arrows = ["← Left", "→ Right", "↓ Down", "↑ Up"]
    }

    private static func keyCount(
        _ label: String,
        daily: Bool,
        today: DayStats,
        globalKeyCounts: [String: Int]
    ) -> Double {
        Double((daily ? today.keyCounts : globalKeyCounts)[label] ?? 0)
    }

    static func totalMouseDistanceCm(in history: [DayStats]) -> Double {
        history.reduce(0) { $0 + $1.mouseDistanceCm }
    }

    /// Nombre de jours actifs consécutifs se terminant à `currentDayKey`.
    /// Un jour est « actif » dès qu'il y a frappes, déplacement ou clics.
    static func streakDays(history: [DayStats], currentDayKey: String) -> Double {
        let activeDays = Set(
            history
                .filter { $0.totalKeystrokes > 0 || $0.mouseDistanceCm > 0 || $0.totalClicks > 0 }
                .map(\.date)
        )
        guard !activeDays.isEmpty,
              var cursor = DateFormatter.dayKey.date(from: currentDayKey) else { return 0 }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var count = 0
        while activeDays.contains(cursor.dayKey) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return Double(count)
    }

    /// Progression vers le seuil (0…1) pour l'affichage des cartes verrouillées.
    static func progress(
        for definition: AchievementDefinition,
        today: DayStats,
        history: [DayStats],
        globalKeyCounts: [String: Int],
        currentDayKey: String
    ) -> Double {
        let (value, _) = currentValue(
            for: definition,
            today: today,
            history: history,
            globalKeyCounts: globalKeyCounts,
            currentDayKey: currentDayKey
        )
        guard definition.threshold > 0 else { return 0 }
        return min(value / definition.threshold, 1)
    }
}
