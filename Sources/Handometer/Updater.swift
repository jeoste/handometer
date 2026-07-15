import AppKit
import Sparkle

/// Encapsule le contrôleur de mises à jour Sparkle.
///
/// L'URL du flux (`SUFeedURL`) et la clé publique EdDSA (`SUPublicEDKey`) sont
/// lues depuis l'`Info.plist` du bundle (injectées par `build.sh`).
///
/// Les mises à jour sont téléchargées automatiquement en arrière-plan. Quand
/// une mise à jour est prête à installer, `updateReady` passe à true et le
/// menu barre propose « Update ready — Restart now » : un clic installe et
/// relance l'app (pattern « install on quit » de Sparkle, déclenché
/// immédiatement via le bloc fourni par le delegate).
@MainActor
final class Updater: NSObject, ObservableObject {
    private var controller: SPUStandardUpdaterController!

    /// Une mise à jour est téléchargée, vérifiée et prête à installer.
    @Published private(set) var updateReady = false
    /// Version de la mise à jour prête (ex. « 1.0.19 »).
    @Published private(set) var readyVersion: String?

    /// Bloc Sparkle qui installe la mise à jour staged et relance l'app.
    private var immediateInstallHandler: (() -> Void)?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        // Vérifie et télécharge automatiquement en arrière-plan.
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.automaticallyDownloadsUpdates = true
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

    /// Installe la mise à jour prête et relance l'app (un clic).
    func installAndRelaunch() {
        immediateInstallHandler?()
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

extension Updater: SPUUpdaterDelegate {
    /// Appelé quand une mise à jour téléchargée est staged pour installation à
    /// la fermeture. Retourner true nous confie le bloc d'installation
    /// immédiate, déclenché par le bouton du menu.
    nonisolated func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        Task { @MainActor in
            self.readyVersion = item.displayVersionString
            self.immediateInstallHandler = immediateInstallHandler
            self.updateReady = true
        }
        return true
    }
}
