import AppKit
import ApplicationServices

/// Gestion de la permission « Accessibilité », requise pour la surveillance
/// globale du clavier.
enum Permissions {
    /// Indique si l'app est déjà autorisée (Accessibilité).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
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
}
