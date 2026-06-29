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

/// Contenu du menu déroulant de la barre de menu.
struct MenuBarContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var updater: Updater
    let openDashboard: () -> Void

    var body: some View {
        Text("Today")
            .font(.headline)
        Text("Mouse: \(TodayView.formatDistance(state.today.mouseDistanceCm))")
        Text("Max speed: \(TodayView.formatSpeed(state.today.maxSpeedKmh))")
        Text("Clicks: \(state.today.totalClicks)")
        Text("Keystrokes: \(state.today.totalKeystrokes)")

        Divider()

        if state.needsAccessibilityRegrant {
            Button("⚠︎ Reset Accessibility…") { state.resetAccessibilityPermission() }
        } else if !state.isTrusted {
            Button("⚠︎ Grant Accessibility…") { state.requestPermission() }
        }
        Button("Open dashboard…", action: openDashboard)
        Toggle("Launch at login", isOn: Binding(
            get: { state.launchAtLogin },
            set: { _ in state.toggleLaunchAtLogin() }
        ))

        Divider()

        Button("Check for updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)

        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
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
