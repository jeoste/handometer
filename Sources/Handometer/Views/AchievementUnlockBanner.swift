import SwiftUI

/// Bannière affichée en haut du dashboard lors d'un nouveau déblocage.
struct AchievementUnlockBanner: View {
    let unlock: UnlockedAchievement
    let onShare: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(unlock.definition.tierColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked!")
                    .font(.subheadline.bold())
                Text("\(unlock.definition.title) — \(unlock.contextLabel())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Share", action: onShare)
                .buttonStyle(.borderedProminent)
                .tint(unlock.definition.tierColor)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(unlock.definition.tierColor.opacity(0.12))
    }
}
