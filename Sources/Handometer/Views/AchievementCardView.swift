import SwiftUI

/// Carte d'achievement style arcade néon.
///
/// Par défaut dimensionnée pour l'UI (~480×270). Passer `forShare: true` pour
/// le rendu export 1200×675 (ImageRenderer) — évite d'allouer un IOSurface
/// plein HD dans le dashboard.
struct AchievementCardView: View {
    let unlock: UnlockedAchievement
    var forShare: Bool = false

    private var definition: AchievementDefinition { unlock.definition }
    private var style: BadgeStyle { definition.badgeStyle }
    private var cardSize: CGSize {
        forShare ? AchievementSharer.cardSize : CGSize(width: 480, height: 270)
    }
    private var scale: CGFloat { forShare ? 1 : 0.4 }

    var body: some View {
        ZStack {
            AchievementBackdrop.gradient(tinted: style.primaryColor)
            ArcadeGridTexture(color: style.primaryColor, spacing: 48 * (forShare ? 1 : 0.7))
            AchievementBackdrop.glow(style.glowColor, radius: 360 * scale)

            VStack(spacing: 26 * scale) {
                topBar

                medal

                VStack(spacing: 12 * scale) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                        .tracking(5 * scale)
                        .foregroundStyle(.white.opacity(0.55))

                    Text(definition.title)
                        .font(.system(size: 54 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .neonGlow(style.primaryColor, radius: 8 * scale)

                    Text(unlock.contextLabel())
                        .font(.system(size: 28 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(style.primaryColor)
                }

                TierPips(tier: definition.tier, color: style.secondaryColor, size: 18 * scale)

                footer
            }
            .padding(48 * scale)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: forShare ? 28 : 12))
        .overlay {
            RoundedRectangle(cornerRadius: forShare ? 28 : 12)
                .stroke(style.borderGradient, lineWidth: forShare ? 5 : 2)
        }
    }

    // MARK: Sous-vues

    private var topBar: some View {
        HStack {
            categoryBadge
            Spacer()
            rarityRibbon
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: 8 * scale) {
            Image(systemName: definition.category.systemImage)
            Text(definition.category.label)
        }
        .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
        .tracking(2 * scale)
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 7 * scale)
        .background(style.primaryColor.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(style.primaryColor.opacity(0.55), lineWidth: forShare ? 1.5 : 1))
        .foregroundStyle(style.primaryColor)
    }

    private var rarityRibbon: some View {
        HStack(spacing: 8 * scale) {
            Text(definition.tier.rarity)
            Text("·")
            Text(unlock.scope == .daily ? "DAILY" : "ALL-TIME")
        }
        .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
        .tracking(2 * scale)
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 7 * scale)
        .background(style.secondaryColor.opacity(0.20), in: Capsule())
        .overlay(Capsule().stroke(style.secondaryColor.opacity(0.6), lineWidth: forShare ? 1.5 : 1))
        .foregroundStyle(style.secondaryColor)
    }

    private var medal: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [style.primaryColor.opacity(0.30), .clear],
                    center: .center, startRadius: 0, endRadius: 110 * scale
                ))
                .frame(width: 200 * scale, height: 200 * scale)

            Circle()
                .stroke(style.neonGradient, lineWidth: definition.tier.ringLineWidth * scale)
                .frame(width: 168 * scale, height: 168 * scale)
                .neonGlow(style.glowColor, radius: style.glowRadius(base: 14) * scale)

            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 150 * scale, height: 150 * scale)

            Image(systemName: definition.systemImage)
                .font(.system(size: 60 * scale, weight: .bold))
                .foregroundStyle(style.primaryColor)
                .neonGlow(style.primaryColor, radius: 10 * scale)
        }
    }

    private var footer: some View {
        VStack(spacing: 14 * scale) {
            Text(unlock.unlockedAt, style: .date)
                .font(.system(size: 16 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            BrandLogoView(height: 28 * scale)
        }
    }
}

/// Miniature de badge pour la grille dans le dashboard.
struct AchievementBadgeTile: View {
    let definition: AchievementDefinition
    let unlock: UnlockedAchievement?
    let progress: Double

    private var isUnlocked: Bool { unlock != nil }
    private var style: BadgeStyle { definition.badgeStyle }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                iconDisc
                Spacer()
                if isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(style.primaryColor)
                        .neonGlow(style.primaryColor, radius: 4)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack(spacing: 6) {
                Text(definition.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Spacer(minLength: 0)
            }

            TierPips(tier: definition.tier, color: isUnlocked ? style.secondaryColor : .secondary, size: 8)

            if let unlock {
                Text(unlock.contextLabel())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(definition.lockedDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)

                ProgressView(value: progress)
                    .tint(style.primaryColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(isUnlocked ? 0.28 : 0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isUnlocked ? AnyShapeStyle(style.borderGradient) : AnyShapeStyle(Color.secondary.opacity(0.25)),
                    lineWidth: isUnlocked ? 1.8 : 1
                )
        }
        .saturation(isUnlocked ? 1 : 0.25)
        .opacity(isUnlocked ? 1 : 0.7)
        .shadow(color: isUnlocked ? style.glowColor.opacity(0.35) : .clear, radius: 8)
    }

    private var iconDisc: some View {
        ZStack {
            Circle()
                .fill(style.primaryColor.opacity(isUnlocked ? 0.18 : 0.08))
                .frame(width: 40, height: 40)
            Image(systemName: definition.systemImage)
                .font(.title3)
                .foregroundStyle(isUnlocked ? style.primaryColor : .secondary)
        }
    }
}
