import AppKit
import ApplicationServices

/// Gestion de la permission « Accessibilité », requise pour la surveillance
/// globale du clavier.
enum Permissions {
    private static let lastLaunchedVersionKey = "lastLaunchedBundleVersion"
    private static let recoveryPromptedVersionKey = "accessibilityRecoveryPromptedForVersion"

    /// Indique si l'app est déjà autorisée (Accessibilité).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Version du bundle courant (`CFBundleVersion`).
    static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// Vérifie l'autorisation et, si nécessaire, affiche la demande système.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Ouvre le volet Accessibilité des Réglages Système.
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Indique si l'app vient d'être mise à jour depuis le dernier lancement.
    static func consumeVersionChange() -> Bool {
        let current = bundleVersion
        guard !current.isEmpty else { return false }
        let previous = UserDefaults.standard.string(forKey: lastLaunchedVersionKey)
        UserDefaults.standard.set(current, forKey: lastLaunchedVersionKey)
        return previous != nil && previous != current
    }

    /// Affiche une fois par version la procédure de réactivation Accessibilité.
    static func promptRegrantIfNeeded(afterUpdate: Bool) {
        let version = bundleVersion
        guard !version.isEmpty else { return }
        guard UserDefaults.standard.string(forKey: recoveryPromptedVersionKey) != version else { return }
        UserDefaults.standard.set(version, forKey: recoveryPromptedVersionKey)

        openSettings()

        let alert = NSAlert()
        alert.alertStyle = .warning
        if afterUpdate {
            alert.messageText = "Re-enable Accessibility After Update"
            alert.informativeText = """
            Handometer was updated. macOS sometimes keeps an old Accessibility permission that no longer works.

            In System Settings, turn Handometer OFF, then ON again. Keystroke counting will resume immediately.
            """
        } else {
            alert.messageText = "Re-enable Accessibility"
            alert.informativeText = """
            Handometer appears authorized but cannot capture keystrokes.

            In System Settings, turn Handometer OFF, then ON again.
            """
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
