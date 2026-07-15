import SwiftUI

/// Onglet classement : opt-in avec pseudo, puis top 50 journalier/hebdo.
struct LeaderboardView: View {
    @ObservedObject var state: AppState

    @State private var period: Leaderboard.Period = .daily
    @State private var standings: Leaderboard.Standings?
    @State private var trophies: [Leaderboard.Trophy] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var optedIn = Leaderboard.isOptedIn
    @State private var name = Leaderboard.displayName

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !Leaderboard.isConfigured {
                    notConfiguredNotice
                } else {
                    optInSection

                    if optedIn {
                        Picker("Period", selection: $period) {
                            Text("Today").tag(Leaderboard.Period.daily)
                            Text("This week").tag(Leaderboard.Period.weekly)
                            Text("All-time").tag(Leaderboard.Period.allTime)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        standingsSection

                        if !trophies.isEmpty {
                            trophyCase
                        }
                    }
                }
            }
            .padding()
        }
        .task(id: period) { await refresh() }
        .onChange(of: optedIn) { newValue in
            Leaderboard.isOptedIn = newValue
            if newValue {
                Task {
                    await Leaderboard.submit(today: state.today)
                    await refresh()
                }
            }
        }
        .onChange(of: name) { Leaderboard.displayName = $0 }
    }

    // MARK: - Sections

    private var notConfiguredNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coming soon", systemImage: "network.slash")
                .font(.headline)
            Text("The online leaderboard backend isn't deployed yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var optInSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Join the leaderboard", isOn: $optedIn)
                .toggleStyle(.switch)

            if optedIn {
                TextField("Nickname", text: $name, prompt: Text("Nickname"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            }

            Text("Only your daily totals are shared (keystrokes, distance, clicks) under a random ID — never which keys you press.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var standingsSection: some View {
        if isLoading && standings == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if loadFailed {
            Label("Couldn't load the leaderboard. Try again later.", systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let standings {
            if let me = standings.me, !standings.entries.contains(where: \.isMe) {
                myRankRow(me)
            }

            if standings.entries.isEmpty {
                Text("No scores yet — be the first!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(standings.entries) { entry in
                        entryRow(entry)
                    }
                }
            }

            Button {
                Task {
                    await Leaderboard.submit(today: state.today)
                    await refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private func entryRow(_ entry: Leaderboard.Entry) -> some View {
        HStack(spacing: 10) {
            Text(rankLabel(entry.rank))
                .font(.subheadline.monospacedDigit().bold())
                .frame(width: 36, alignment: .trailing)
            Text(entry.name)
                .font(.subheadline.weight(entry.isMe ? .bold : .regular))
                .lineLimit(1)
            if entry.trophies > 0 {
                Text("🏆\(entry.trophies)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if entry.isMe {
                Text("YOU")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.2), in: Capsule())
            }
            Spacer()
            Text("\(entry.score) XP")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            entry.isMe ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func myRankRow(_ me: Leaderboard.Standings.MyRank) -> some View {
        Label("Your rank: #\(me.rank) — \(me.score) XP", systemImage: "person.fill")
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Vitrine de trophées

    /// Podiums de fin de période remportés (jour, semaine, mois, trimestre, année).
    private var trophyCase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Trophy case", systemImage: "trophy.fill")
                .font(.headline)

            ForEach(trophies) { trophy in
                HStack(spacing: 10) {
                    Text(rankLabel(trophy.rank))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(periodLabel(trophy.period)) champion — \(trophy.periodKey)")
                            .font(.subheadline.weight(.semibold))
                        Text("Rank #\(trophy.rank) · \(trophy.score) XP scored")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+\(trophy.xp) XP")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.top, 4)
    }

    private func periodLabel(_ period: String) -> String {
        switch period {
        case "day":     return "Daily"
        case "week":    return "Weekly"
        case "month":   return "Monthly"
        case "quarter": return "Quarterly"
        case "year":    return "Yearly"
        default:        return period.capitalized
        }
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }

    // MARK: - Chargement

    private func refresh() async {
        guard Leaderboard.isConfigured, optedIn else { return }
        isLoading = true
        loadFailed = false
        do {
            standings = try await Leaderboard.fetchStandings(
                period: period,
                dayKey: state.currentDayKey
            )
        } catch {
            loadFailed = true
        }
        // Collection de trophées : silencieux en cas d'échec (cache conservé).
        if let collection = try? await Leaderboard.fetchTrophies() {
            trophies = collection.trophies
        }
        isLoading = false
    }
}
