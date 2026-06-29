import SwiftUI

/// Carte d'achievement style arcade néon, dimensionnée pour le partage X (1200×675).
struct AchievementCardView: View {
    let unlock: UnlockedAchievement

    private var definition: AchievementDefinition { unlock.definition }
    private var style: BadgeStyle { definition.badgeStyle }

    var body: some View {
        ZStack {
            AchievementBackdrop.gradient(tinted: style.primaryColor)
            ArcadeGridTexture(color: style.primaryColor, spacing: 48)
            AchievementBackdrop.glow(style.glowColor, radius: 360)

            VStack(spacing: 26) {
                topBar

                medal

                VStack(spacing: 12) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.55))

                    Text(definition.title)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .neonGlow(style.primaryColor, radius: 8)

                    Text(unlock.contextLabel())
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(style.primaryColor)
                }

                TierPips(tier: definition.tier, color: style.secondaryColor, size: 18)

                footer
            }
            .padding(48)
        }
        .frame(width: AchievementSharer.cardSize.width, height: AchievementSharer.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(style.borderGradient, lineWidth: 5)
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
        HStack(spacing: 8) {
            Image(systemName: definition.category.systemImage)
            Text(definition.category.label)
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
        .tracking(2)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(style.primaryColor.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(style.primaryColor.opacity(0.55), lineWidth: 1.5))
        .foregroundStyle(style.primaryColor)
    }

    private var rarityRibbon: some View {
        HStack(spacing: 8) {
            Text(definition.tier.rarity)
            Text("·")
            Text(unlock.scope == .daily ? "DAILY" : "ALL-TIME")
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
        .tracking(2)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(style.secondaryColor.opacity(0.20), in: Capsule())
        .overlay(Capsule().stroke(style.secondaryColor.opacity(0.6), lineWidth: 1.5))
        .foregroundStyle(style.secondaryColor)
    }

    private var medal: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [style.primaryColor.opacity(0.30), .clear],
                    center: .center, startRadius: 0, endRadius: 110
                ))
                .frame(width: 200, height: 200)

            Circle()
                .stroke(style.neonGradient, lineWidth: definition.tier.ringLineWidth)
                .frame(width: 168, height: 168)
                .neonGlow(style.glowColor, radius: style.glowRadius(base: 14))

            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 150, height: 150)

            Image(systemName: definition.systemImage)
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(style.primaryColor)
                .neonGlow(style.primaryColor, radius: 10)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text(unlock.unlockedAt, style: .date)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 18, weight: .bold))
                Text("Handometer")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.4))
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
