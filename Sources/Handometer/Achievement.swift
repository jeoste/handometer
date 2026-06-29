import Foundation
import SwiftUI

enum AchievementScope: String, Codable, CaseIterable {
    case daily
    case allTime
}

enum AchievementKind: String, Codable, CaseIterable {
    case key100
    case key500
    case mouse1km
}

struct AchievementDefinition: Identifiable {
    let kind: AchievementKind
    let scope: AchievementScope

    var id: String { "\(kind.rawValue)_\(scope.rawValue)" }

    var title: String {
        switch (kind, scope) {
        case (.key100, .daily): return "Key Crusher 100"
        case (.key500, .daily): return "Key Crusher 500"
        case (.key100, .allTime): return "Key Veteran 100"
        case (.key500, .allTime): return "Key Veteran 500"
        case (.mouse1km, .daily): return "Marathon Mouse"
        case (.mouse1km, .allTime): return "Marathon Mouse Legend"
        }
    }

    var lockedDescription: String {
        switch kind {
        case .key100: return "Press any key 100 times"
        case .key500: return "Press any key 500 times"
        case .mouse1km: return "Move your mouse 1 km"
        }
    }

    var systemImage: String {
        switch kind {
        case .key100, .key500: return "keyboard.fill"
        case .mouse1km: return "cursorarrow.motionlines"
        }
    }

    var tierColor: Color {
        switch kind {
        case .key100: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        case .key500: return Color(red: 0.75, green: 0.75, blue: 0.80)   // silver
        case .mouse1km: return Color(red: 0.95, green: 0.78, blue: 0.25) // gold
        }
    }

    var threshold: Double {
        switch kind {
        case .key100: return 100
        case .key500: return 500
        case .mouse1km: return 100_000 // cm
        }
    }

    static let all: [AchievementDefinition] = AchievementScope.allCases.flatMap { scope in
        AchievementKind.allCases.map { AchievementDefinition(kind: $0, scope: scope) }
    }
}

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
        switch kind {
        case .key100, .key500:
            let key = contextKey ?? "?"
            let count = Int(contextValue)
            let period = scope == .daily ? "today" : "all-time"
            return "\(key) × \(count) \(period)"
        case .mouse1km:
            let km = contextValue / 100
            let period = scope == .daily ? "today" : "all-time"
            return String(format: "%.2f km \(period)", km)
        }
    }

    func shareText() -> String {
        "Just unlocked \(definition.title) on Handometer — \(contextLabel()) 🏆"
    }
}
