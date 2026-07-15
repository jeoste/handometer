import SwiftUI

/// Niveau de progression du joueur, calculé à la volée depuis les statistiques
/// cumulées (jamais persisté : pas de compteur à maintenir, rétroactif et sans
/// dérive possible).
///
/// Barème XP :
///   - 1 frappe        = 1 XP
///   - 1 cm de souris  = 0,1 XP
///   - 1 clic          = 2 XP
///   - achievement     = bonus selon le palier (voir `AchievementTier.xpBonus`)
///
/// Courbe : XP totale pour atteindre le niveau L = 200 × (L−1)².
/// Niveau 2 en quelques minutes, ~50 en deux mois, 100 à 2 M XP (plusieurs
/// mois d'usage régulier). Après le niveau 100, prestige : retour au niveau 1
/// avec une icône différente et une étoile supplémentaire.
struct PlayerLevel {
    let prestige: Int
    /// Niveau courant dans le cycle (1…100).
    let level: Int
    /// XP accumulée depuis le début du niveau courant.
    let xpIntoLevel: Double
    /// XP nécessaire pour passer du début du niveau courant au suivant.
    let xpForNextLevel: Double
    let lifetimeXP: Double

    // MARK: Barème

    static let xpPerKeystroke = 1.0
    static let xpPerCm = 0.1
    static let xpPerClick = 2.0

    /// Constante de la courbe quadratique.
    static let curveConstant = 200.0
    /// XP d'un cycle complet (niveau 1 → prestige).
    static let cycleXP = curveConstant * 100 * 100 // 2 000 000

    /// XP totale (dans le cycle) requise pour atteindre un niveau donné.
    static func totalXP(forLevel level: Int) -> Double {
        curveConstant * Double(level - 1) * Double(level - 1)
    }

    init(lifetimeXP: Double) {
        let xp = max(0, lifetimeXP)
        self.lifetimeXP = xp
        self.prestige = Int(xp / Self.cycleXP)
        let inCycle = xp - Double(prestige) * Self.cycleXP
        let level = min(100, Int((inCycle / Self.curveConstant).squareRoot()) + 1)
        self.level = level
        let start = Self.totalXP(forLevel: level)
        let next = level >= 100 ? Self.cycleXP : Self.totalXP(forLevel: level + 1)
        self.xpIntoLevel = inCycle - start
        self.xpForNextLevel = next - start
    }

    /// Progression vers le niveau suivant (0…1).
    var progress: Double {
        xpForNextLevel > 0 ? min(xpIntoLevel / xpForNextLevel, 1) : 1
    }

    // MARK: Apparence du prestige

    private static let prestigeMarks: [(icon: String, color: Color)] = [
        ("hand.raised.fill",     Color(red: 0.55, green: 0.62, blue: 0.72)), // acier
        ("flame.fill",           Color(red: 0.99, green: 0.44, blue: 0.14)), // flamme
        ("bolt.fill",            Color(red: 0.99, green: 0.82, blue: 0.16)), // foudre
        ("crown.fill",           Color(red: 0.99, green: 0.68, blue: 0.21)), // couronne
        ("sparkles",             Color(red: 0.72, green: 0.36, blue: 0.99)), // arcane
        ("moon.stars.fill",      Color(red: 0.42, green: 0.55, blue: 0.99)), // cosmos
        ("sun.max.fill",         Color(red: 0.99, green: 0.55, blue: 0.10)), // étoile
        ("diamond.fill",         Color(red: 0.70, green: 0.93, blue: 0.96)), // diamant
        ("infinity.circle.fill", Color(red: 0.13, green: 0.92, blue: 0.98))  // infini
    ]

    /// Icône du rang de prestige courant (plafonnée au dernier rang défini).
    var prestigeIcon: String {
        Self.prestigeMarks[min(prestige, Self.prestigeMarks.count - 1)].icon
    }

    /// Couleur du rang de prestige courant.
    var prestigeColor: Color {
        Self.prestigeMarks[min(prestige, Self.prestigeMarks.count - 1)].color
    }
}

extension AchievementTier {
    /// XP bonus accordée quand un achievement de ce palier est débloqué.
    /// Les achievements quotidiens se redébloquent chaque jour : bonus récurrent.
    var xpBonus: Double {
        switch self {
        case .bronze:   return 500
        case .silver:   return 1_500
        case .gold:     return 4_000
        case .platinum: return 8_000
        case .diamond:  return 15_000
        }
    }
}

// MARK: - Vue

/// Bandeau de niveau compact : icône de prestige, niveau, étoiles et barre d'XP.
struct LevelBadgeView: View {
    let playerLevel: PlayerLevel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(playerLevel.prestigeColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Circle()
                    .stroke(playerLevel.prestigeColor.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 40, height: 40)
                Image(systemName: playerLevel.prestigeIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(playerLevel.prestigeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Level \(playerLevel.level)")
                        .font(.subheadline.bold())
                    if playerLevel.prestige > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<playerLevel.prestige, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(playerLevel.prestigeColor)
                            }
                        }
                    }
                    Spacer()
                    Text("\(AchievementMetric.grouped(playerLevel.xpIntoLevel)) / \(AchievementMetric.grouped(playerLevel.xpForNextLevel)) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: playerLevel.progress)
                    .tint(playerLevel.prestigeColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
