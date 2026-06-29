import SwiftUI

/// Onglet achievements : collection groupée par catégorie, filtrable par scope.
struct AchievementsView: View {
    @ObservedObject var state: AppState

    @State private var scope: AchievementScope = .daily

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var featuredUnlock: UnlockedAchievement? {
        state.pendingUnlock ?? state.achievements.first
    }

    /// Catégories proposées pour le scope sélectionné, dans l'ordre de la charte.
    private var categories: [AchievementCategory] {
        let present = Set(
            AchievementDefinition.all
                .filter { $0.scope == scope }
                .map(\.category)
        )
        return AchievementCategory.allCases
            .filter { present.contains($0) }
            .sorted { $0.sortIndex < $1.sortIndex }
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

                Picker("Scope", selection: $scope) {
                    Text("Today").tag(AchievementScope.daily)
                    Text("All-time").tag(AchievementScope.allTime)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                let unlocks = state.achievements(for: scope)
                ForEach(categories, id: \.self) { category in
                    categorySection(category: category, unlocks: unlocks)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func categorySection(
        category: AchievementCategory,
        unlocks: [UnlockedAchievement]
    ) -> some View {
        let definitions = AchievementDefinition.all
            .filter { $0.scope == scope && $0.category == category }
        let unlockedCount = definitions.filter { def in
            unlocks.contains { $0.kind == def.kind }
        }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .foregroundStyle(category.accent)
                Text(category.label)
                    .font(.headline)
                Spacer()
                Text("\(unlockedCount)/\(definitions.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(definitions) { definition in
                    let unlock = unlocks.first { $0.kind == definition.kind }
                    let progress = AchievementEvaluator.progress(
                        for: definition,
                        today: state.today,
                        history: state.history,
                        globalKeyCounts: state.globalKeyCounts,
                        currentDayKey: state.currentDayKey
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
}
