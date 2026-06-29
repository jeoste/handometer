import SwiftUI

/// Carte d'achievement style gaming, dimensionnée pour le partage X (1200×675).
struct AchievementCardView: View {
    let unlock: UnlockedAchievement

    private var definition: AchievementDefinition { unlock.definition }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.18),
                    Color(red: 0.14, green: 0.06, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glow behind the medal.
            RadialGradient(
                colors: [definition.tierColor.opacity(0.35), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )

            VStack(spacing: 28) {
                scopeBadge

                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    definition.tierColor,
                                    definition.tierColor.opacity(0.5),
                                    definition.tierColor,
                                    Color.white.opacity(0.6),
                                    definition.tierColor
                                ],
                                center: .center
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 160, height: 160)

                    Circle()
                        .fill(definition.tierColor.opacity(0.2))
                        .frame(width: 140, height: 140)

                    Image(systemName: definition.systemImage)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(definition.tierColor)
                        .shadow(color: definition.tierColor.opacity(0.8), radius: 12)
                }

                VStack(spacing: 12) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.55))

                    Text(definition.title)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(unlock.contextLabel())
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(definition.tierColor)
                }

                Text(unlock.unlockedAt, style: .date)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 18, weight: .bold))
                    Text("Handometer")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.35))
            }
            .padding(48)
        }
        .frame(width: AchievementSharer.cardSize.width, height: AchievementSharer.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            definition.tierColor,
                            definition.tierColor.opacity(0.4),
                            definition.tierColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 5
                )
        }
    }

    private var scopeBadge: some View {
        Text(unlock.scope == .daily ? "DAILY" : "ALL-TIME")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .tracking(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(definition.tierColor.opacity(0.25), in: Capsule())
            .foregroundStyle(definition.tierColor)
    }
}

/// Miniature de badge pour la grille dans le dashboard.
struct AchievementBadgeTile: View {
    let definition: AchievementDefinition
    let unlock: UnlockedAchievement?
    let progress: Double

    private var isUnlocked: Bool { unlock != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: definition.systemImage)
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? definition.tierColor : .secondary)
                Spacer()
                if isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(definition.tierColor)
                }
            }

            Text(definition.title)
                .font(.subheadline.bold())
                .foregroundStyle(isUnlocked ? .primary : .secondary)

            if let unlock {
                Text(unlock.contextLabel())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(definition.lockedDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ProgressView(value: progress)
                    .tint(definition.tierColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(isUnlocked ? 0.5 : 0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? definition.tierColor.opacity(0.5) : .clear, lineWidth: 1.5)
        }
        .opacity(isUnlocked ? 1 : 0.55)
    }
}
