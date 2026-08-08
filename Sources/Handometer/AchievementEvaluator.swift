import Foundation

/// Instantané des données nécessaires pour évaluer les achievements, construit
/// une fois par passe (une évaluation, ou un render de la vue).
///
/// Classe et non struct pour que `streakDays` soit mémoïsé : il coûte ~93 µs et
/// il était recalculé pour chacune des 6 définitions de série — donc six fois
/// par passe, et deux fois par render dans `AchievementsView`. Calculé
/// paresseusement : une passe où toutes les séries sont déjà débloquées ne le
/// demande jamais.
final class MetricContext {
    let today: DayStats
    let history: [DayStats]
    let globalKeyCounts: [String: Int]
    let currentDayKey: String

    private var cachedStreak: Double?

    init(today: DayStats, history: [DayStats], globalKeyCounts: [String: Int], currentDayKey: String) {
        self.today = today
        self.history = history
        self.globalKeyCounts = globalKeyCounts
        self.currentDayKey = currentDayKey
    }

    /// Nombre de jours actifs consécutifs se terminant à `currentDayKey`.
    var streakDays: Double {
        if let cachedStreak { return cachedStreak }
        let value = AchievementEvaluator.streakDays(history: history, currentDayKey: currentDayKey)
        cachedStreak = value
        return value
    }
}

enum AchievementEvaluator {
    static func evaluate(
        context: MetricContext,
        alreadyUnlockedKeys existingKeys: Set<String>,
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
                    uniquenessKey = "\(kind.rawValue)_\(scope.rawValue)_\(context.currentDayKey)"
                } else {
                    uniquenessKey = "\(kind.rawValue)_\(scope.rawValue)"
                }
                guard !existingKeys.contains(uniquenessKey) else { continue }

                if let unlock = check(definition: definition, context: context) {
                    results.append(unlock)
                }
            }
        }

        return results
    }

    private static func check(
        definition: AchievementDefinition,
        context: MetricContext
    ) -> UnlockedAchievement? {
        let (value, contextKey) = currentValue(for: definition, context: context)
        guard definition.threshold > 0, value >= definition.threshold else { return nil }

        return UnlockedAchievement(
            kind: definition.kind,
            scope: definition.scope,
            dayKey: definition.scope == .daily ? context.currentDayKey : nil,
            contextKey: contextKey,
            contextValue: value
        )
    }

    /// Valeur courante d'une métrique pour un scope donné, et clé de contexte
    /// éventuelle (ex. la touche la plus pressée). Source unique partagée par
    /// `check` (déblocage) et `progress` (affichage).
    static func currentValue(
        for definition: AchievementDefinition,
        context: MetricContext
    ) -> (value: Double, contextKey: String?) {
        let daily = definition.scope == .daily
        let today = context.today
        let history = context.history

        switch definition.metric {
        case .topKeyCount:
            let counts = daily ? today.keyCounts : context.globalKeyCounts
            guard let best = counts.max(by: { $0.value < $1.value }) else { return (0, nil) }
            return (Double(best.value), best.key)

        case .totalKeystrokes:
            return (Double(daily ? today.totalKeystrokes : history.totalKeystrokes), nil)

        case .mouseDistanceCm:
            return (daily ? today.mouseDistanceCm : history.totalMouseDistanceCm, nil)

        case .totalClicks:
            return (Double(daily ? today.totalClicks : history.totalClicks), nil)

        case .rightClicks:
            return (Double(daily ? today.rightClicks : history.reduce(0) { $0 + $1.rightClicks }), nil)

        case .middleClicks:
            return (Double(daily ? today.middleClicks : history.reduce(0) { $0 + $1.middleClicks }), nil)

        case .maxSpeedKmh:
            let value = daily ? today.maxSpeedKmh : (history.map(\.maxSpeedKmh).max() ?? 0)
            return (value, nil)

        case .streakDays:
            return (context.streakDays, nil)

        case .spaceKeys:
            return (keyCount(SpecialKey.space, daily: daily, context: context), nil)

        case .backspaceKeys:
            return (keyCount(SpecialKey.backspace, daily: daily, context: context), nil)

        case .escKeys:
            return (keyCount(SpecialKey.esc, daily: daily, context: context), nil)

        case .enterKeys:
            return (keyCount(SpecialKey.enter, daily: daily, context: context), nil)

        case .arrowKeys:
            let total = SpecialKey.arrows.reduce(0.0) {
                $0 + keyCount($1, daily: daily, context: context)
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

    private static func keyCount(_ label: String, daily: Bool, context: MetricContext) -> Double {
        Double((daily ? context.today.keyCounts : context.globalKeyCounts)[label] ?? 0)
    }

    /// Calendrier partagé : en construire un par appel coûtait l'essentiel du
    /// temps de `streakDays`.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    /// Nombre de jours actifs consécutifs se terminant à `currentDayKey`.
    /// Un jour est « actif » dès qu'il y a frappes, déplacement ou clics.
    /// Passer par `MetricContext.streakDays`, qui mémoïse.
    static func streakDays(history: [DayStats], currentDayKey: String) -> Double {
        let activeDays = Set(
            history
                .filter { $0.totalKeystrokes > 0 || $0.mouseDistanceCm > 0 || $0.totalClicks > 0 }
                .map(\.date)
        )
        guard !activeDays.isEmpty,
              var cursor = DateFormatter.dayKey.date(from: currentDayKey) else { return 0 }

        var count = 0
        while activeDays.contains(cursor.dayKey) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return Double(count)
    }

    /// Progression vers le seuil (0…1) pour l'affichage des cartes verrouillées.
    static func progress(for definition: AchievementDefinition, context: MetricContext) -> Double {
        let (value, _) = currentValue(for: definition, context: context)
        guard definition.threshold > 0 else { return 0 }
        return min(value / definition.threshold, 1)
    }
}
