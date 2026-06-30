import AppKit
import Sparkle

/// Encapsule le contrôleur de mises à jour Sparkle.
///
/// L'URL du flux (`SUFeedURL`) et la clé publique EdDSA (`SUPublicEDKey`) sont
/// lues depuis l'`Info.plist` du bundle (injectées par `build.sh`).
@MainActor
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Vérifie automatiquement les mises à jour en arrière-plan.
        controller.updater.automaticallyChecksForUpdates = true
    }

    /// Lance une vérification manuelle (depuis le menu).
    ///
    /// Handometer est une app « agent » (`LSUIElement` / `.accessory`) : sans
    /// activation préalable, la fenêtre Sparkle s'ouvre en arrière-plan au 1er
    /// clic (l'app n'est pas au premier plan) et l'utilisateur doit cliquer une
    /// 2e fois pour que Sparkle la ramène devant via `showUpdateInFocus`. On
    /// active donc l'app avant de lancer la vérification.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
    }

    /// Indique si une vérification est possible (flux configuré).
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    /// Vérification automatique en arrière-plan (Sparkle).
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
