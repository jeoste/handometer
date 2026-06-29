import SwiftUI

/// Onglet achievements : collection quotidienne et all-time avec partage.
struct AchievementsView: View {
    @ObservedObject var state: AppState

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var featuredUnlock: UnlockedAchievement? {
        state.pendingUnlock ?? state.achievements.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let latest = featuredUnlock {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest unlock")
                            .font(.headline)

                        AchievementCardView(unlock: latest)
                            .frame(maxWidth: 480)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 8)

                        Button {
                            AchievementSharer.shareOnX(unlock: latest)
                        } label: {
                            Label("Share on X", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                achievementSection(
                    title: "Today",
                    scope: .daily,
                    unlocks: state.achievements(for: .daily)
                )

                achievementSection(
                    title: "All-time",
                    scope: .allTime,
                    unlocks: state.achievements(for: .allTime)
                )
            }
            .padding()
        }
    }

    @ViewBuilder
    private func achievementSection(
        title: String,
        scope: AchievementScope,
        unlocks: [UnlockedAchievement]
    ) -> some View {
        Text(title)
            .font(.headline)

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AchievementDefinition.all.filter { $0.scope == scope }) { definition in
                let unlock = unlocks.first { $0.kind == definition.kind }
                let progress = AchievementEvaluator.progress(
                    for: definition,
                    today: state.today,
                    history: state.history,
                    globalKeyCounts: state.globalKeyCounts
                )

                AchievementBadgeTile(
                    definition: definition,
                    unlock: unlock,
                    progress: progress
                )
                .contextMenu {
                    if let unlock {
                        Button("Share on X") {
                            AchievementSharer.shareOnX(unlock: unlock)
                        }
                    }
                }
            }
        }
    }
}
