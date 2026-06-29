import Foundation
import SwiftUI

enum AchievementScope: String, Codable, CaseIterable {
    case daily
    case allTime

    /// Suffixe utilisé dans les libellés contextuels.
    var period: String { self == .daily ? "today" : "all-time" }
}

// MARK: - Métrique mesurée

/// Décrit *quoi* mesurer pour un achievement. Sépare la donnée du palier visuel.
enum AchievementMetric: String, Codable {
    case topKeyCount        // frappes sur une même touche
    case totalKeystrokes    // total de frappes
    case mouseDistanceCm    // distance curseur, en cm
    case totalClicks        // total de clics
    case rightClicks        // clics droits
    case middleClicks       // clics molette
    case maxSpeedKmh        // vitesse curseur max, en km/h
    case streakDays         // jours actifs consécutifs

    /// Scopes pour lesquels la métrique a du sens.
    var allowedScopes: [AchievementScope] {
        switch self {
        case .streakDays: return [.allTime]
        default:          return [.daily, .allTime]
        }
    }

    /// Libellé contextuel d'un unlock (valeur atteinte).
    func contextLabel(value: Double, contextKey: String?, scope: AchievementScope) -> String {
        switch self {
        case .topKeyCount:
            return "\(contextKey ?? "?") × \(Int(value)) \(scope.period)"
        case .totalKeystrokes:
            return "\(Self.grouped(value)) keys \(scope.period)"
        case .mouseDistanceCm:
            return "\(Self.distance(cm: value)) \(scope.period)"
        case .totalClicks:
            return "\(Self.grouped(value)) clicks \(scope.period)"
        case .rightClicks:
            return "\(Self.grouped(value)) right-clicks \(scope.period)"
        case .middleClicks:
            return "\(Self.grouped(value)) middle-clicks \(scope.period)"
        case .maxSpeedKmh:
            return String(format: "%.1f km/h %@", value, scope.period)
        case .streakDays:
            return "\(Int(value))-day streak"
        }
    }

    /// Description de l'objectif (carte verrouillée).
    func lockedDescription(threshold: Double) -> String {
        switch self {
        case .topKeyCount:
            return "Press a single key \(Self.grouped(threshold)) times"
        case .totalKeystrokes:
            return "Type \(Self.grouped(threshold)) keystrokes"
        case .mouseDistanceCm:
            return "Move your mouse \(Self.distance(cm: threshold))"
        case .totalClicks:
            return "Click \(Self.grouped(threshold)) times"
        case .rightClicks:
            return "Right-click \(Self.grouped(threshold)) times"
        case .middleClicks:
            return "Middle-click \(Self.grouped(threshold)) times"
        case .maxSpeedKmh:
            return String(format: "Reach %.0f km/h cursor speed", threshold)
        case .streakDays:
            return "Stay active \(Int(threshold)) days in a row"
        }
    }

    // MARK: Formatage

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func grouped(_ value: Double) -> String {
        groupingFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
    }

    /// Formate une distance en cm vers une chaîne lisible (m / km).
    static func distance(cm: Double) -> String {
        let meters = cm / 100
        if meters >= 1_000 {
            return String(format: "%.2f km", meters / 1_000)
        }
        return String(format: "%.0f m", meters)
    }
}

// MARK: - Définition d'un achievement

enum AchievementKind: String, Codable, CaseIterable {
    // Clavier — touche unique (rawValues historiques conservées).
    case key100
    case key500
    // Clavier — volume total.
    case keysTotal1k
    case keysTotal10k
    case keysTotal100k
    case keysTotal1m
    // Souris — distance.
    case mouse100m
    case mouse1km
    case mouse5km
    case mouse10km
    case mouseMarathon
    // Clics.
    case clicks1k
    case clicks10k
    case clicks100k
    case rightClicks1k
    case middleClicks100
    // Vitesse.
    case speed5
    case speed10
    case speed20
    // Séries.
    case streak3
    case streak7
    case streak30
}

/// Caractéristiques figées d'un type d'achievement.
private struct AchievementSpec {
    let metric: AchievementMetric
    let threshold: Double
    let category: AchievementCategory
    let tier: AchievementTier
    let title: String
    let systemImage: String?
    /// Restreint éventuellement les scopes (sous-ensemble de `metric.allowedScopes`).
    let scopeOverride: [AchievementScope]?
}

struct AchievementDefinition: Identifiable {
    let kind: AchievementKind
    let scope: AchievementScope

    var id: String { "\(kind.rawValue)_\(scope.rawValue)" }

    private var spec: AchievementSpec { AchievementDefinition.spec(for: kind) }

    var metric: AchievementMetric { spec.metric }
    var threshold: Double { spec.threshold }
    var category: AchievementCategory { spec.category }
    var tier: AchievementTier { spec.tier }
    var title: String { spec.title }
    var systemImage: String { spec.systemImage ?? spec.category.systemImage }

    var badgeStyle: BadgeStyle { BadgeStyle(category: category, tier: tier) }

    /// Teinte dominante — conservée pour compatibilité avec les vues.
    var tierColor: Color { badgeStyle.primaryColor }

    var lockedDescription: String { metric.lockedDescription(threshold: threshold) }

    /// Scopes pour lesquels CE type est proposé.
    static func applicableScopes(for kind: AchievementKind) -> [AchievementScope] {
        let spec = spec(for: kind)
        let allowed = spec.metric.allowedScopes
        guard let override = spec.scopeOverride else { return allowed }
        return override.filter { allowed.contains($0) }
    }

    /// Toutes les définitions valides (kind × scopes applicables).
    static let all: [AchievementDefinition] = AchievementKind.allCases.flatMap { kind in
        applicableScopes(for: kind).map { AchievementDefinition(kind: kind, scope: $0) }
    }

    // MARK: Table des specs

    private static func spec(for kind: AchievementKind) -> AchievementSpec {
        switch kind {
        // Clavier — touche unique
        case .key100:
            return .init(metric: .topKeyCount, threshold: 100, category: .keyboard, tier: .bronze, title: "Key Crusher", systemImage: nil, scopeOverride: nil)
        case .key500:
            return .init(metric: .topKeyCount, threshold: 500, category: .keyboard, tier: .silver, title: "Key Smasher", systemImage: nil, scopeOverride: nil)
        // Clavier — volume
        case .keysTotal1k:
            return .init(metric: .totalKeystrokes, threshold: 1_000, category: .keyboard, tier: .bronze, title: "Warming Up", systemImage: nil, scopeOverride: nil)
        case .keysTotal10k:
            return .init(metric: .totalKeystrokes, threshold: 10_000, category: .keyboard, tier: .silver, title: "Wordsmith", systemImage: nil, scopeOverride: nil)
        case .keysTotal100k:
            return .init(metric: .totalKeystrokes, threshold: 100_000, category: .keyboard, tier: .gold, title: "Keyboard Warrior", systemImage: nil, scopeOverride: nil)
        case .keysTotal1m:
            return .init(metric: .totalKeystrokes, threshold: 1_000_000, category: .keyboard, tier: .diamond, title: "Million Keys", systemImage: "crown.fill", scopeOverride: [.allTime])
        // Souris — distance (seuils en cm)
        case .mouse100m:
            return .init(metric: .mouseDistanceCm, threshold: 10_000, category: .mouse, tier: .bronze, title: "First Steps", systemImage: nil, scopeOverride: nil)
        case .mouse1km:
            return .init(metric: .mouseDistanceCm, threshold: 100_000, category: .mouse, tier: .silver, title: "Marathon Mouse", systemImage: nil, scopeOverride: nil)
        case .mouse5km:
            return .init(metric: .mouseDistanceCm, threshold: 500_000, category: .mouse, tier: .gold, title: "Trail Blazer", systemImage: nil, scopeOverride: nil)
        case .mouse10km:
            return .init(metric: .mouseDistanceCm, threshold: 1_000_000, category: .mouse, tier: .platinum, title: "Long Hauler", systemImage: nil, scopeOverride: nil)
        case .mouseMarathon:
            return .init(metric: .mouseDistanceCm, threshold: 4_219_500, category: .mouse, tier: .diamond, title: "Marathoner", systemImage: "figure.run", scopeOverride: [.allTime])
        // Clics
        case .clicks1k:
            return .init(metric: .totalClicks, threshold: 1_000, category: .clicks, tier: .bronze, title: "Click Starter", systemImage: nil, scopeOverride: nil)
        case .clicks10k:
            return .init(metric: .totalClicks, threshold: 10_000, category: .clicks, tier: .silver, title: "Click Machine", systemImage: nil, scopeOverride: nil)
        case .clicks100k:
            return .init(metric: .totalClicks, threshold: 100_000, category: .clicks, tier: .gold, title: "Click Tornado", systemImage: nil, scopeOverride: [.allTime])
        case .rightClicks1k:
            return .init(metric: .rightClicks, threshold: 1_000, category: .clicks, tier: .silver, title: "Context Master", systemImage: "contextualmenu.and.cursorarrow", scopeOverride: nil)
        case .middleClicks100:
            return .init(metric: .middleClicks, threshold: 100, category: .clicks, tier: .gold, title: "Wheel Deal", systemImage: "computermouse.fill", scopeOverride: nil)
        // Vitesse
        case .speed5:
            return .init(metric: .maxSpeedKmh, threshold: 5, category: .speed, tier: .bronze, title: "Quick Draw", systemImage: nil, scopeOverride: nil)
        case .speed10:
            return .init(metric: .maxSpeedKmh, threshold: 10, category: .speed, tier: .silver, title: "Speed Demon", systemImage: nil, scopeOverride: nil)
        case .speed20:
            return .init(metric: .maxSpeedKmh, threshold: 20, category: .speed, tier: .gold, title: "Lightning Hands", systemImage: nil, scopeOverride: nil)
        // Séries
        case .streak3:
            return .init(metric: .streakDays, threshold: 3, category: .streak, tier: .bronze, title: "On a Roll", systemImage: nil, scopeOverride: nil)
        case .streak7:
            return .init(metric: .streakDays, threshold: 7, category: .streak, tier: .silver, title: "Week Warrior", systemImage: nil, scopeOverride: nil)
        case .streak30:
            return .init(metric: .streakDays, threshold: 30, category: .streak, tier: .gold, title: "Unstoppable", systemImage: nil, scopeOverride: nil)
        }
    }
}

// MARK: - Achievement débloqué

struct UnlockedAchievement: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: AchievementKind
    let scope: AchievementScope
    let unlockedAt: Date
    let dayKey: String?
    let contextKey: String?
    let contextValue: Double

    init(
        id: UUID = UUID(),
        kind: AchievementKind,
        scope: AchievementScope,
        unlockedAt: Date = Date(),
        dayKey: String? = nil,
        contextKey: String? = nil,
        contextValue: Double
    ) {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.unlockedAt = unlockedAt
        self.dayKey = dayKey
        self.contextKey = contextKey
        self.contextValue = contextValue
    }

    var definition: AchievementDefinition {
        AchievementDefinition(kind: kind, scope: scope)
    }

    var uniquenessKey: String {
        if scope == .daily, let dayKey {
            return "\(kind.rawValue)_\(scope.rawValue)_\(dayKey)"
        }
        return "\(kind.rawValue)_\(scope.rawValue)"
    }

    func contextLabel() -> String {
        definition.metric.contextLabel(value: contextValue, contextKey: contextKey, scope: scope)
    }

    func shareText() -> String {
        "Just unlocked \(definition.title) on Handometer — \(contextLabel()) 🏆"
    }
}
