import SwiftUI
import AppKit

@main
struct HandometerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var updater = Updater()
    @Environment(\.openWindow) private var openWindow
    @State private var settingsTab: SettingsTab = .general

    var body: some Scene {
        // Fenêtre dashboard (ouverte à la demande depuis le menu).
        Window("Handometer", id: "dashboard") {
            DashboardView(state: state)
                .onAppear { state.start() }
        }
        .windowResizability(.contentMinSize)

        Window("Settings", id: "settings") {
            SettingsView(state: state, updater: updater, selectedTab: $settingsTab)
        }
        .windowResizability(.contentSize)

        // Icône barre de menu avec résumé rapide.
        MenuBarExtra {
            MenuBarContent(
                state: state,
                openDashboard: {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                },
                openSettings: { tab in
                    settingsTab = tab
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
            .onAppear { state.start() }
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
    }

    /// Icône custom de la barre de menu (template monochrome bundlé dans
    /// l'app), avec repli sur un symbole système si la ressource manque.
    static let menuBarIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "menubar@2x", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }
        let fallback = NSImage(systemSymbolName: "cursorarrow.motionlines",
                               accessibilityDescription: "Handometer")
            ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }()
}

/// Instantané des stats affichées dans le menu (rafraîchi périodiquement, pas à
/// chaque événement souris/clavier, pour éviter les re-rendus qui cassent le
/// surlignage et les clics dans `MenuBarExtra`).
private struct MenuBarStatsSnapshot {
    var mouseDistance = ""
    var maxSpeed = ""
    var clicks = 0
    var keystrokes = 0

    init() {}

    init(from stats: DayStats) {
        mouseDistance = TodayView.formatDistance(stats.mouseDistanceCm)
        maxSpeed = TodayView.formatSpeed(stats.maxSpeedKmh)
        clicks = stats.totalClicks
        keystrokes = stats.totalKeystrokes
    }
}

/// Contenu du menu déroulant de la barre de menu.
struct MenuBarContent: View {
    let state: AppState
    let openDashboard: () -> Void
    let openSettings: (SettingsTab) -> Void

    @State private var stats = MenuBarStatsSnapshot()
    @State private var isTrusted = Permissions.isTrusted
    @State private var needsAccessibilityRegrant = false
    @State private var refreshTimer: Timer?

    var body: some View {
        Group {
            Button("Today") {}
                .font(.headline)
                .disabled(true)
            Button("Mouse: \(stats.mouseDistance)") {}
                .disabled(true)
            Button("Max speed: \(stats.maxSpeed)") {}
                .disabled(true)
            Button("Clicks: \(stats.clicks)") {}
                .disabled(true)
            Button("Keystrokes: \(stats.keystrokes)") {}
                .disabled(true)

            Divider()

            if needsAccessibilityRegrant {
                Button("⚠︎ Reset Accessibility…") { state.resetAccessibilityPermission() }
            } else if !isTrusted {
                Button("⚠︎ Grant Accessibility…") { state.requestPermission() }
            }
            Button("Open dashboard…", action: openDashboard)
            Button("Settings…") { openSettings(.general) }

            Divider()

            Button("About Handometer…") { openSettings(.about) }
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .onAppear { startMenuRefresh() }
        .onDisappear { stopMenuRefresh() }
    }

    @MainActor
    private func startMenuRefresh() {
        refreshFromState()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in refreshFromState() }
        }
    }

    private func stopMenuRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    private func refreshFromState() {
        stats = MenuBarStatsSnapshot(from: state.today)
        isTrusted = state.isTrusted
        needsAccessibilityRegrant = state.needsAccessibilityRegrant
    }
}

/// Délégué applicatif : configure la politique d'activation et déclenche la
/// demande de permission au lancement.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // pas d'icône Dock
        Permissions.requestIfNeeded()
    }
}
