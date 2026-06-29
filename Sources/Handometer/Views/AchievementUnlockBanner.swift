import SwiftUI

/// Bannière affichée en haut du dashboard lors d'un nouveau déblocage.
struct AchievementUnlockBanner: View {
    let unlock: UnlockedAchievement
    let onShare: () -> Void
    let onDismiss: () -> Void

    private var definition: AchievementDefinition { unlock.definition }
    private var style: BadgeStyle { definition.badgeStyle }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(style.primaryColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: definition.systemImage)
                    .font(.title3)
                    .foregroundStyle(style.primaryColor)
                    .neonGlow(style.primaryColor, radius: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Achievement unlocked!")
                        .font(.subheadline.bold())
                    Text(definition.tier.rarity)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(style.secondaryColor.opacity(0.25), in: Capsule())
                        .foregroundStyle(style.secondaryColor)
                }
                Text("\(definition.title) — \(unlock.contextLabel())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Share", action: onShare)
                .buttonStyle(.borderedProminent)
                .tint(style.primaryColor)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(style.primaryColor.opacity(0.12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(style.primaryColor)
                .frame(width: 3)
        }
    }
}
