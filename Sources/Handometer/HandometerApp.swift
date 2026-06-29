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
        MenuBarExtra("Handometer", systemImage: "cursorarrow.motionlines") {
            MenuBarContent(state: state, updater: updater) {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            .onAppear { state.start() }
        }
    }
}

/// Contenu du menu déroulant de la barre de menu.
struct MenuBarContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var updater: Updater
    let openDashboard: () -> Void

    var body: some View {
        Text("Aujourd'hui")
            .font(.headline)
        Text("Souris : \(TodayView.formatDistance(state.today.mouseDistanceCm))")
        Text("Frappes : \(state.today.totalKeystrokes)")

        Divider()

        if !state.isTrusted {
            Button("⚠︎ Autoriser l'Accessibilité…") { state.requestPermission() }
        }
        Button("Ouvrir le dashboard…", action: openDashboard)
        Toggle("Démarrer à la connexion", isOn: Binding(
            get: { state.launchAtLogin },
            set: { _ in state.toggleLaunchAtLogin() }
        ))

        Divider()

        Button("Rechercher les mises à jour…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)

        Button("Quitter") { NSApp.terminate(nil) }
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
