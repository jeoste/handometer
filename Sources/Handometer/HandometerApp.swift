import SwiftUI
import AppKit

@main
struct HandometerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var updater = Updater()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Fenêtre dashboard (ouverte à la demande depuis le menu).
        Window("Handometer", id: "dashboard") {
            DashboardView(state: state)
                .onAppear { state.start() }
        }
        .windowResizability(.contentMinSize)

        // Icône barre de menu avec résumé rapide.
        MenuBarExtra {
            MenuBarContent(state: state, updater: updater) {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
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
    var averageSpeed = ""
    var maxSpeed = ""
    var clicks = 0
    var keystrokes = 0

    init() {}

    init(from stats: DayStats) {
        mouseDistance = TodayView.formatDistance(stats.mouseDistanceCm)
        averageSpeed = TodayView.formatSpeed(stats.averageSpeedKmh)
        maxSpeed = TodayView.formatSpeed(stats.maxSpeedKmh)
        clicks = stats.totalClicks
        keystrokes = stats.totalKeystrokes
    }

    var headerText: String {
        """
        Today
        Mouse: \(mouseDistance)
        Avg speed: \(averageSpeed)
        Max speed: \(maxSpeed)
        Clicks: \(clicks)
        Keystrokes: \(keystrokes)
        """
    }
}

/// Contenu du menu déroulant de la barre de menu.
struct MenuBarContent: View {
    let state: AppState
    let updater: Updater
    let openDashboard: () -> Void

    @State private var stats = MenuBarStatsSnapshot()
    @State private var isTrusted = Permissions.isTrusted
    @State private var needsAccessibilityRegrant = false
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var refreshTimer: Timer?

    var body: some View {
        Section {
            if needsAccessibilityRegrant {
                Button("⚠︎ Reset Accessibility…") { state.resetAccessibilityPermission() }
            } else if !isTrusted {
                Button("⚠︎ Grant Accessibility…") { state.requestPermission() }
            }
            Button("Open dashboard…", action: openDashboard)
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { _ in
                    state.toggleLaunchAtLogin()
                    launchAtLogin = state.launchAtLogin
                }
            ))
        } header: {
            // Un seul Text : plusieurs `Text` dans un menu sont rendus comme
            // entrées cliquables (surlignage bleu au survol).
            Text(stats.headerText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(nil)
                .allowsHitTesting(false)
        }

        Section {
            Button("Check for updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .onAppear { startMenuRefresh() }
        .onDisappear { stopMenuRefresh() }
    }

    private func startMenuRefresh() {
        refreshFromState()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { refreshFromState() }
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
        launchAtLogin = state.launchAtLogin
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
