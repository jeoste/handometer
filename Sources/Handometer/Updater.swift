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
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Indique si une vérification est possible (flux configuré).
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
