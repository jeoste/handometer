import SwiftUI
import AppKit

enum SettingsTab: Hashable {
    case general
    case about
}

/// Fenêtre Réglages : onglet Général + About (dernier onglet).
struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var updater: Updater
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsPane(state: state)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AboutSettingsPane(updater: updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 420, height: 340)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutSettingsPane: View {
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 8) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                Text("Handometer")
                    .font(.title2.bold())

                Text(AppInfo.versionLine)
                    .font(.body)

                if let builtLine = AppInfo.builtLine {
                    Text(builtLine)
                        .font(.body)
                }

                Text("A pedometer for your hands — track cursor distance and keystrokes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }

            VStack(spacing: 6) {
                Link(destination: AppInfo.githubURL) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))

                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Text("© 2026 Jeoffrey Stéphan. MIT License.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 10)
        }
    }
}
