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
    // Métriques « exotiques » dérivées de keyCounts / DayStats.
    case spaceKeys          // frappes sur la barre d'espace
    case backspaceKeys      // frappes sur Backspace
    case escKeys            // frappes sur Esc
    case enterKeys          // frappes sur Enter
    case arrowKeys          // frappes cumulées sur les 4 flèches
    case uniqueKeys         // touches distinctes pressées dans la journée
    case movementSeconds    // temps cumulé de déplacement souris, en secondes

    /// Scopes pour lesquels la métrique a du sens.
    var allowedScopes: [AchievementScope] {
        switch self {
        case .streakDays:  return [.allTime]
        case .uniqueKeys:  return [.daily]   // all-time : tout clavier finit couvert
        default:           return [.daily, .allTime]
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
            return "\(UnitPreferences.shared.formatDistance(cm: value)) \(scope.period)"
        case .totalClicks:
            return "\(Self.grouped(value)) clicks \(scope.period)"
        case .rightClicks:
            return "\(Self.grouped(value)) right-clicks \(scope.period)"
        case .middleClicks:
            return "\(Self.grouped(value)) middle-clicks \(scope.period)"
        case .maxSpeedKmh:
            return "\(UnitPreferences.shared.formatSpeed(kmh: value)) \(scope.period)"
        case .streakDays:
            return "\(Int(value))-day streak"
        case .spaceKeys:
            return "\(Self.grouped(value)) space bar hits \(scope.period)"
        case .backspaceKeys:
            return "\(Self.grouped(value)) backspaces \(scope.period)"
        case .escKeys:
            return "\(Self.grouped(value)) escapes \(scope.period)"
        case .enterKeys:
            return "\(Self.grouped(value)) enters \(scope.period)"
        case .arrowKeys:
            return "\(Self.grouped(value)) arrow presses \(scope.period)"
        case .uniqueKeys:
            return "\(Int(value)) distinct keys \(scope.period)"
        case .movementSeconds:
            return "\(Self.duration(value)) of motion \(scope.period)"
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
            return "Move your mouse \(UnitPreferences.shared.formatDistance(cm: threshold))"
        case .totalClicks:
            return "Click \(Self.grouped(threshold)) times"
        case .rightClicks:
            return "Right-click \(Self.grouped(threshold)) times"
        case .middleClicks:
            return "Middle-click \(Self.grouped(threshold)) times"
        case .maxSpeedKmh:
            let speed = UnitPreferences.shared.formatSpeed(kmh: threshold)
            return "Reach \(speed) cursor speed"
        case .streakDays:
            return "Stay active \(Int(threshold)) days in a row"
        case .spaceKeys:
            return "Hit the space bar \(Self.grouped(threshold)) times"
        case .backspaceKeys:
            return "Press Backspace \(Self.grouped(threshold)) times"
        case .escKeys:
            return "Press Esc \(Self.grouped(threshold)) times"
        case .enterKeys:
            return "Press Enter \(Self.grouped(threshold)) times"
        case .arrowKeys:
            return "Press the arrow keys \(Self.grouped(threshold)) times"
        case .uniqueKeys:
            return "Press \(Int(threshold)) different keys in one day"
        case .movementSeconds:
            return "Keep the cursor moving for \(Self.duration(threshold))"
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

    /// Formatage compact d'une durée en secondes (« 45 min », « 2h », « 100h »).
    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest) min"
    }
}

// MARK: - Définition d'un achievement

enum AchievementKind: String, Codable, CaseIterable {
    // Clavier — touche unique (rawValues historiques conservées).
    case key100
    case key500
    case key1k
    // Clavier — volume total.
    case keysTotal1k
    case keysTotal10k
    case keysTotal100k
    case keysTotal500k
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
    case clicks1m
    case rightClicks1k
    case rightClicks10k
    case middleClicks100
    case middleClicks1k
    // Vitesse.
    case speed5
    case speed10
    case speed20
    case speed30
    case speed50
    // Séries.
    case streak3
    case streak7
    case streak14
    case streak30
    case streak100
    case streak365
    // Exotiques.
    case spaceCadet
    case spaceStation
    case secondThoughts
    case eraserPro
    case escapeArtist
    case sendIt
    case arrowPilot
    case keyboardTour
    case restlessHands
    case manualLabor
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
            return .init(metric: .topKeyCount, threshold: 100, category: .keyboard, tier: .bronze, title: "Key Crusher", systemImage: "hammer.fill", scopeOverride: nil)
        case .key500:
            return .init(metric: .topKeyCount, threshold: 500, category: .keyboard, tier: .silver, title: "Key Smasher", systemImage: "hammer.circle.fill", scopeOverride: nil)
        case .key1k:
            return .init(metric: .topKeyCount, threshold: 1_000, category: .keyboard, tier: .gold, title: "Key Obliterator", systemImage: "burst.fill", scopeOverride: nil)
        // Clavier — volume
        case .keysTotal1k:
            return .init(metric: .totalKeystrokes, threshold: 1_000, category: .keyboard, tier: .bronze, title: "Warming Up", systemImage: "sun.min.fill", scopeOverride: nil)
        case .keysTotal10k:
            return .init(metric: .totalKeystrokes, threshold: 10_000, category: .keyboard, tier: .silver, title: "Wordsmith", systemImage: "text.book.closed.fill", scopeOverride: nil)
        case .keysTotal100k:
            return .init(metric: .totalKeystrokes, threshold: 100_000, category: .keyboard, tier: .gold, title: "Keyboard Warrior", systemImage: "shield.fill", scopeOverride: nil)
        case .keysTotal500k:
            return .init(metric: .totalKeystrokes, threshold: 500_000, category: .keyboard, tier: .platinum, title: "Half-Million March", systemImage: "flag.checkered", scopeOverride: [.allTime])
        case .keysTotal1m:
            return .init(metric: .totalKeystrokes, threshold: 1_000_000, category: .keyboard, tier: .diamond, title: "Million Keys", systemImage: "crown.fill", scopeOverride: [.allTime])
        // Souris — distance (seuils en cm)
        case .mouse100m:
            return .init(metric: .mouseDistanceCm, threshold: 10_000, category: .mouse, tier: .bronze, title: "First Steps", systemImage: "figure.walk", scopeOverride: nil)
        case .mouse1km:
            return .init(metric: .mouseDistanceCm, threshold: 100_000, category: .mouse, tier: .silver, title: "Marathon Mouse", systemImage: "figure.hiking", scopeOverride: nil)
        case .mouse5km:
            return .init(metric: .mouseDistanceCm, threshold: 500_000, category: .mouse, tier: .gold, title: "Trail Blazer", systemImage: "map.fill", scopeOverride: nil)
        case .mouse10km:
            return .init(metric: .mouseDistanceCm, threshold: 1_000_000, category: .mouse, tier: .platinum, title: "Long Hauler", systemImage: "car.fill", scopeOverride: nil)
        case .mouseMarathon:
            return .init(metric: .mouseDistanceCm, threshold: 4_219_500, category: .mouse, tier: .diamond, title: "Marathoner", systemImage: "figure.run", scopeOverride: [.allTime])
        // Clics
        case .clicks1k:
            return .init(metric: .totalClicks, threshold: 1_000, category: .clicks, tier: .bronze, title: "Click Starter", systemImage: "cursorarrow.click", scopeOverride: nil)
        case .clicks10k:
            return .init(metric: .totalClicks, threshold: 10_000, category: .clicks, tier: .silver, title: "Click Machine", systemImage: "gearshape.2.fill", scopeOverride: nil)
        case .clicks100k:
            return .init(metric: .totalClicks, threshold: 100_000, category: .clicks, tier: .gold, title: "Click Tornado", systemImage: "tornado", scopeOverride: [.allTime])
        case .clicks1m:
            return .init(metric: .totalClicks, threshold: 1_000_000, category: .clicks, tier: .diamond, title: "Click Millionaire", systemImage: "dollarsign.circle.fill", scopeOverride: [.allTime])
        case .rightClicks1k:
            return .init(metric: .rightClicks, threshold: 1_000, category: .clicks, tier: .silver, title: "Context Master", systemImage: "contextualmenu.and.cursorarrow", scopeOverride: nil)
        case .rightClicks10k:
            return .init(metric: .rightClicks, threshold: 10_000, category: .clicks, tier: .gold, title: "Menu Connoisseur", systemImage: "filemenu.and.selection", scopeOverride: [.allTime])
        case .middleClicks100:
            return .init(metric: .middleClicks, threshold: 100, category: .clicks, tier: .gold, title: "Wheel Deal", systemImage: "computermouse.fill", scopeOverride: nil)
        case .middleClicks1k:
            return .init(metric: .middleClicks, threshold: 1_000, category: .clicks, tier: .platinum, title: "Wheel Lord", systemImage: "steeringwheel", scopeOverride: [.allTime])
        // Vitesse
        case .speed5:
            return .init(metric: .maxSpeedKmh, threshold: 5, category: .speed, tier: .bronze, title: "Quick Draw", systemImage: "hare.fill", scopeOverride: nil)
        case .speed10:
            return .init(metric: .maxSpeedKmh, threshold: 10, category: .speed, tier: .silver, title: "Speed Demon", systemImage: "bolt.horizontal.fill", scopeOverride: nil)
        case .speed20:
            return .init(metric: .maxSpeedKmh, threshold: 20, category: .speed, tier: .gold, title: "Lightning Hands", systemImage: "bolt.fill", scopeOverride: nil)
        case .speed30:
            return .init(metric: .maxSpeedKmh, threshold: 30, category: .speed, tier: .platinum, title: "Supersonic", systemImage: "airplane", scopeOverride: nil)
        case .speed50:
            return .init(metric: .maxSpeedKmh, threshold: 50, category: .speed, tier: .diamond, title: "Warp Speed", systemImage: "wand.and.stars", scopeOverride: nil)
        // Séries
        case .streak3:
            return .init(metric: .streakDays, threshold: 3, category: .streak, tier: .bronze, title: "On a Roll", systemImage: "flame", scopeOverride: nil)
        case .streak7:
            return .init(metric: .streakDays, threshold: 7, category: .streak, tier: .silver, title: "Week Warrior", systemImage: "calendar", scopeOverride: nil)
        case .streak14:
            return .init(metric: .streakDays, threshold: 14, category: .streak, tier: .gold, title: "Fortnight Force", systemImage: "calendar.badge.clock", scopeOverride: nil)
        case .streak30:
            return .init(metric: .streakDays, threshold: 30, category: .streak, tier: .platinum, title: "Unstoppable", systemImage: "flame.fill", scopeOverride: nil)
        case .streak100:
            return .init(metric: .streakDays, threshold: 100, category: .streak, tier: .diamond, title: "Century Club", systemImage: "trophy.fill", scopeOverride: nil)
        case .streak365:
            return .init(metric: .streakDays, threshold: 365, category: .streak, tier: .diamond, title: "Year of the Hand", systemImage: "sun.max.fill", scopeOverride: nil)
        // Exotiques
        case .spaceCadet:
            return .init(metric: .spaceKeys, threshold: 2_000, category: .exotic, tier: .silver, title: "Space Cadet", systemImage: "moon.stars.fill", scopeOverride: nil)
        case .spaceStation:
            return .init(metric: .spaceKeys, threshold: 100_000, category: .exotic, tier: .gold, title: "Space Station", systemImage: "globe.americas.fill", scopeOverride: [.allTime])
        case .secondThoughts:
            return .init(metric: .backspaceKeys, threshold: 500, category: .exotic, tier: .silver, title: "Second Thoughts", systemImage: "arrow.uturn.backward.circle.fill", scopeOverride: nil)
        case .eraserPro:
            return .init(metric: .backspaceKeys, threshold: 50_000, category: .exotic, tier: .gold, title: "Professional Eraser", systemImage: "eraser.fill", scopeOverride: [.allTime])
        case .escapeArtist:
            return .init(metric: .escKeys, threshold: 100, category: .exotic, tier: .silver, title: "Escape Artist", systemImage: "door.left.hand.open", scopeOverride: nil)
        case .sendIt:
            return .init(metric: .enterKeys, threshold: 1_000, category: .exotic, tier: .silver, title: "Send It", systemImage: "paperplane.fill", scopeOverride: nil)
        case .arrowPilot:
            return .init(metric: .arrowKeys, threshold: 5_000, category: .exotic, tier: .gold, title: "Arrow Pilot", systemImage: "gamecontroller.fill", scopeOverride: nil)
        case .keyboardTour:
            return .init(metric: .uniqueKeys, threshold: 60, category: .exotic, tier: .gold, title: "Full Keyboard Tour", systemImage: "pianokeys", scopeOverride: nil)
        case .restlessHands:
            return .init(metric: .movementSeconds, threshold: 3_600, category: .exotic, tier: .gold, title: "Restless Hands", systemImage: "timer", scopeOverride: [.daily])
        case .manualLabor:
            return .init(metric: .movementSeconds, threshold: 360_000, category: .exotic, tier: .platinum, title: "Manual Labor", systemImage: "hourglass", scopeOverride: [.allTime])
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
