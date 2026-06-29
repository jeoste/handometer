import SwiftUI

/// Fenêtre principale : onglets « Aujourd'hui » et « Historique », bannière de
/// permission, et actions (export, démarrage auto).
struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !state.isTrusted {
                permissionBanner
            }

            TabView {
                TodayView(state: state)
                    .tabItem { Label("Aujourd'hui", systemImage: "calendar") }

                HistoryChartView(history: state.history)
                    .tabItem { Label("Historique", systemImage: "chart.bar.xaxis") }
            }

            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 460)
        .onAppear { state.refresh() }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Accessibilité requise")
                    .font(.subheadline.bold())
                Text("Sans elle, les frappes clavier ne peuvent pas être comptées.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Ouvrir les Réglages") { state.openPermissionSettings() }
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }

    private var footer: some View {
        HStack {
            Toggle("Démarrer à la connexion", isOn: Binding(
                get: { state.launchAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                Exporter.exportCSV(days: state.allDays)
            } label: {
                Label("Export CSV", systemImage: "tablecells")
            }

            Button {
                Exporter.exportJSON(days: state.allDays)
            } label: {
                Label("Export JSON", systemImage: "curlybraces")
            }
        }
        .padding(12)
    }
}
