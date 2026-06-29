import Foundation
import ServiceManagement

/// Active/désactive le démarrage automatique de l'app à la connexion via
/// `SMAppService` (macOS 13+).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Active ou désactive le lancement au login. Retourne le nouvel état.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Handometer: échec login item — \(error)")
        }
        return isEnabled
    }
}
