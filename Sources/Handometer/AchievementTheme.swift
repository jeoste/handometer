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

    /// Tokens de la catégorie, en un seul switch exhaustif. L'ordre d'affichage
    /// des sections est l'ordre de déclaration (`allCases`).
    private var tokens: (accent: Color, label: String, systemImage: String) {
        switch self {
        case .keyboard: return (Color(red: 0.13, green: 0.92, blue: 0.98), "KEYBOARD", "keyboard.fill")          // cyan électrique
        case .mouse:    return (Color(red: 0.98, green: 0.20, blue: 0.66), "MOUSE", "cursorarrow.motionlines")   // magenta néon
        case .clicks:   return (Color(red: 0.46, green: 0.98, blue: 0.32), "CLICKS", "cursorarrow.click.2")      // vert lime
        case .speed:    return (Color(red: 0.99, green: 0.82, blue: 0.16), "SPEED", "bolt.fill")                 // ambre néon
        case .streak:   return (Color(red: 0.99, green: 0.44, blue: 0.14), "STREAK", "flame.fill")               // orange flamme
        case .exotic:   return (Color(red: 0.72, green: 0.36, blue: 0.99), "EXOTIC", "sparkles")                 // violet ovni
        }
    }

    var accent: Color { tokens.accent }
    var label: String { tokens.label }
    var systemImage: String { tokens.systemImage }
}

/// Palier de prestige d'un achievement. Module l'**intensité** (glow, anneau,
/// reflet) et porte le libellé de rareté.
enum AchievementTier: String, Codable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond

    /// Tokens du palier, en un seul switch exhaustif : libellé de rareté, reflet
    /// métallique, facteur de halo (1 = base) et épaisseur de l'anneau.
    private var tokens: (rarity: String, sheen: Color, glowScale: CGFloat, ringLineWidth: CGFloat) {
        switch self {
        case .bronze:   return ("COMMON",    Color(red: 0.85, green: 0.55, blue: 0.30), 0.80, 6)
        case .silver:   return ("RARE",      Color(red: 0.86, green: 0.88, blue: 0.94), 1.00, 7)
        case .gold:     return ("EPIC",      Color(red: 0.99, green: 0.84, blue: 0.36), 1.25, 9)
        case .platinum: return ("LEGENDARY", Color(red: 0.70, green: 0.93, blue: 0.96), 1.50, 11)
        case .diamond:  return ("MYTHIC",    Color(red: 0.78, green: 0.72, blue: 0.99), 1.85, 13)
        }
    }

    var rarity: String { tokens.rarity }
    var sheen: Color { tokens.sheen }
    var glowScale: CGFloat { tokens.glowScale }
    var ringLineWidth: CGFloat { tokens.ringLineWidth }

    /// Nombre d'étoiles affichées (1…5) : le rang du palier.
    var pipCount: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
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
    /// Fond arcade quasi-noir, identique pour tous les badges.
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.03, blue: 0.07),
            Color(red: 0.06, green: 0.04, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
