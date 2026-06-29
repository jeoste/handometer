import AppKit
import ApplicationServices

/// Résultat d'une tentative de reset TCC Accessibilité.
enum AccessibilityResetResult {
    case success
    case cancelled
    case failed(String)
}

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

    /// Identifiant du bundle (utilisé par `tccutil`).
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.jeoste.handometer"
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

    /// Supprime l'entrée Accessibilité de Handometer dans TCC (demande le mot de
    /// passe admin). L'utilisateur pourra ensuite recocher l'app dans les Réglages.
    static func resetAccessibilityEntry() -> AccessibilityResetResult {
        let bundleID = bundleIdentifier
        let script = """
        do shell script "/usr/bin/tccutil reset Accessibility \(bundleID)" with administrator privileges
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failed("Could not create reset script.")
        }
        appleScript.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -128 {
                return .cancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return .failed(message)
        }
        return .success
    }

    /// Indique si l'app vient d'être mise à jour depuis le dernier lancement.
    static func consumeVersionChange() -> Bool {
        let current = bundleVersion
        guard !current.isEmpty else { return false }
        let previous = UserDefaults.standard.string(forKey: lastLaunchedVersionKey)
        UserDefaults.standard.set(current, forKey: lastLaunchedVersionKey)
        return previous != nil && previous != current
    }

    /// Propose le reset TCC une fois par version (après mise à jour ou permission
    /// fantôme). Retourne `true` si l'utilisateur a confirmé le reset.
    static func offerAccessibilityReset(afterUpdate: Bool) -> Bool {
        let version = bundleVersion
        guard !version.isEmpty else { return false }
        guard UserDefaults.standard.string(forKey: recoveryPromptedVersionKey) != version else { return false }

        let alert = NSAlert()
        alert.alertStyle = .warning
        if afterUpdate {
            alert.messageText = "Reset Accessibility After Update"
            alert.informativeText = """
            Handometer was updated and macOS kept a stale Accessibility permission that no longer works.

            Click Reset Permission to remove it (your Mac password is required), then enable Handometer again in System Settings.
            """
        } else {
            alert.messageText = "Reset Accessibility Permission"
            alert.informativeText = """
            Handometer appears authorized but cannot capture keystrokes.

            Click Reset Permission to remove the stale entry (your Mac password is required), then enable Handometer again in System Settings.
            """
        }
        alert.addButton(withTitle: "Reset Permission")
        alert.addButton(withTitle: "Later")

        UserDefaults.standard.set(version, forKey: recoveryPromptedVersionKey)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func showResetFailure(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Could Not Reset Accessibility"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
