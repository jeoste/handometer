import SwiftUI

// MARK: - Charte graphique « arcade néon »
//
// Tous les tokens visuels des badges vivent ici : couleurs néon par catégorie,
// intensité par palier (tier) et la struct `BadgeStyle` que les vues consomment.
// Aucune couleur de badge ne doit être codée en dur ailleurs.

/// Famille thématique d'un achievement. Donne la **teinte** néon dominante.
enum AchievementCategory: String, Codable, CaseIterable {
    case keyboard
    case mouse
    case clicks
    case speed
    case streak
    case exotic

    /// Couleur néon principale de la catégorie.
    var accent: Color {
        switch self {
        case .keyboard: return Color(red: 0.13, green: 0.92, blue: 0.98) // cyan électrique
        case .mouse:    return Color(red: 0.98, green: 0.20, blue: 0.66) // magenta néon
        case .clicks:   return Color(red: 0.46, green: 0.98, blue: 0.32) // vert lime
        case .speed:    return Color(red: 0.99, green: 0.82, blue: 0.16) // ambre néon
        case .streak:   return Color(red: 0.99, green: 0.44, blue: 0.14) // orange flamme
        case .exotic:   return Color(red: 0.72, green: 0.36, blue: 0.99) // violet ovni
        }
    }

    /// Libellé court affiché sur les cartes / sections.
    var label: String {
        switch self {
        case .keyboard: return "KEYBOARD"
        case .mouse:    return "MOUSE"
        case .clicks:   return "CLICKS"
        case .speed:    return "SPEED"
        case .streak:   return "STREAK"
        case .exotic:   return "EXOTIC"
        }
    }

    /// Icône SF Symbol par défaut de la catégorie.
    var systemImage: String {
        switch self {
        case .keyboard: return "keyboard.fill"
        case .mouse:    return "cursorarrow.motionlines"
        case .clicks:   return "cursorarrow.click.2"
        case .speed:    return "bolt.fill"
        case .streak:   return "flame.fill"
        case .exotic:   return "sparkles"
        }
    }

    /// Ordre d'affichage stable des sections.
    var sortIndex: Int {
        switch self {
        case .keyboard: return 0
        case .mouse:    return 1
        case .clicks:   return 2
        case .speed:    return 3
        case .streak:   return 4
        case .exotic:   return 5
        }
    }
}

/// Palier de prestige d'un achievement. Module l'**intensité** (glow, anneau,
/// reflet) et porte le libellé de rareté.
enum AchievementTier: String, Codable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond

    /// Libellé de rareté affiché sur le ruban.
    var rarity: String {
        switch self {
        case .bronze:   return "COMMON"
        case .silver:   return "RARE"
        case .gold:     return "EPIC"
        case .platinum: return "LEGENDARY"
        case .diamond:  return "MYTHIC"
        }
    }

    /// Reflet métallique superposé à l'accent de la catégorie.
    var sheen: Color {
        switch self {
        case .bronze:   return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .silver:   return Color(red: 0.86, green: 0.88, blue: 0.94)
        case .gold:     return Color(red: 0.99, green: 0.84, blue: 0.36)
        case .platinum: return Color(red: 0.70, green: 0.93, blue: 0.96)
        case .diamond:  return Color(red: 0.78, green: 0.72, blue: 0.99)
        }
    }

    /// Facteur d'intensité du halo (1 = base).
    var glowScale: CGFloat {
        switch self {
        case .bronze:   return 0.8
        case .silver:   return 1.0
        case .gold:     return 1.25
        case .platinum: return 1.5
        case .diamond:  return 1.85
        }
    }

    /// Épaisseur de l'anneau de la médaille (carte de partage).
    var ringLineWidth: CGFloat {
        switch self {
        case .bronze:   return 6
        case .silver:   return 7
        case .gold:     return 9
        case .platinum: return 11
        case .diamond:  return 13
        }
    }

    /// Nombre d'étoiles affichées (1…5) pour indiquer le palier.
    var pipCount: Int {
        switch self {
        case .bronze:   return 1
        case .silver:   return 2
        case .gold:     return 3
        case .platinum: return 4
        case .diamond:  return 5
        }
    }
}

/// Combinaison `(catégorie, palier)` résolue en tokens prêts à l'emploi par les
/// vues. C'est le seul point d'entrée graphique pour un badge.
struct BadgeStyle {
    let category: AchievementCategory
    let tier: AchievementTier

    /// Teinte dominante (donnée par la catégorie).
    var primaryColor: Color { category.accent }

    /// Reflet métallique du palier, pour les dégradés et highlights.
    var secondaryColor: Color { tier.sheen }

    /// Couleur du halo lumineux.
    var glowColor: Color { category.accent }

    /// Rayon de halo conseillé pour une vue donnée (multiplié par le palier).
    func glowRadius(base: CGFloat) -> CGFloat { base * tier.glowScale }

    var rarityLabel: String { tier.rarity }

    /// Dégradé arcade utilisé pour les anneaux et bordures néon.
    var neonGradient: AngularGradient {
        AngularGradient(
            colors: [
                primaryColor,
                secondaryColor,
                primaryColor.opacity(0.6),
                .white.opacity(0.85),
                primaryColor
            ],
            center: .center
        )
    }

    /// Bordure linéaire néon (cartes, tuiles).
    var borderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor.opacity(0.7), primaryColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Fonds & textures partagés

enum AchievementBackdrop {
    /// Fond arcade quasi-noir teinté par la couleur du badge.
    static func gradient(tinted color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.03, blue: 0.07),
                Color(red: 0.06, green: 0.04, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Nappe radiale néon centrée derrière la médaille.
    static func glow(_ color: Color, radius: CGFloat = 320) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(0.40), color.opacity(0.08), .clear],
            center: .center,
            startRadius: 10,
            endRadius: radius
        )
    }
}

/// Grille rétro-arcade en perspective légère, dessinée via `Canvas`.
struct ArcadeGridTexture: View {
    var color: Color
    var spacing: CGFloat = 34
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let stroke = GraphicsContext.Shading.color(color.opacity(0.10))
            var x: CGFloat = 0
            while x <= size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: stroke, lineWidth: lineWidth)
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: stroke, lineWidth: lineWidth)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Rangée d'étoiles indiquant le palier.
struct TierPips: View {
    let tier: AchievementTier
    var color: Color
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < tier.pipCount ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < tier.pipCount ? color : color.opacity(0.25))
            }
        }
    }
}

extension View {
    /// Halo néon réutilisable (plusieurs ombres empilées).
    func neonGlow(_ color: Color, radius: CGFloat) -> some View {
        self
            .shadow(color: color.opacity(0.9), radius: radius * 0.4)
            .shadow(color: color.opacity(0.6), radius: radius)
    }
}
