import SwiftUI

/// Fenêtre principale : onglets « Aujourd'hui » et « Historique », bannière de
/// permission, et actions (export, démarrage auto).
struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if state.needsAccessibilityRegrant {
                accessibilityRegrantBanner
            } else if !state.isTrusted {
                permissionBanner
            }

            TabView {
                TodayView(state: state)
                    .tabItem { Label("Today", systemImage: "calendar") }

                HistoryChartView(history: state.history)
                    .tabItem { Label("History", systemImage: "chart.bar.xaxis") }
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
                Text("Accessibility permission required")
                    .font(.subheadline.bold())
                Text("Without it, keystrokes and clicks can't be counted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { state.openPermissionSettings() }
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }

    private var accessibilityRegrantBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reset Accessibility after update")
                    .font(.subheadline.bold())
                Text("Removes the stale permission so you can re-enable Handometer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset Permission") { state.resetAccessibilityPermission() }
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: Binding(
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
