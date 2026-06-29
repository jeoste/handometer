import AppKit

/// Surveille globalement les mouvements de souris et les frappes clavier.
///
/// Utilise à la fois un *global monitor* (événements destinés aux autres apps)
/// et un *local monitor* (événements destinés à notre propre app) afin de ne
/// rien manquer. La capture du clavier nécessite la permission Accessibilité.
final class EventMonitor {
    private var globalMonitors: [Any] = []
    private var localMonitor: Any?

    /// Appelé pour chaque segment de déplacement souris : (distance px, point global).
    var onMouseMove: ((Double, CGPoint) -> Void)?
    /// Appelé pour chaque frappe : libellé de la touche.
    var onKeyDown: ((String) -> Void)?

    private let mouseMask: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]
    private let keyMask: NSEvent.EventTypeMask = [.keyDown]

    func start() {
        // Global : événements des autres applications.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] in
            self?.handleMouse($0)
        }) {
            globalMonitors.append(m)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: keyMask, handler: { [weak self] in
            self?.handleKey($0)
        }) {
            globalMonitors.append(m)
        }

        // Local : événements destinés à notre propre fenêtre (dashboard ouvert).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask.union(keyMask)) { [weak self] event in
            if self?.mouseMask.contains(NSEvent.EventTypeMask(type: event.type)) == true {
                self?.handleMouse(event)
            } else if event.type == .keyDown {
                self?.handleKey(event)
            }
            return event
        }
    }

    func stop() {
        for m in globalMonitors { NSEvent.removeMonitor(m) }
        globalMonitors.removeAll()
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
    }

    // MARK: - Handlers

    private func handleMouse(_ event: NSEvent) {
        let dx = event.deltaX
        let dy = event.deltaY
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0 else { return }
        onMouseMove?(distance, NSEvent.mouseLocation)
    }

    private func handleKey(_ event: NSEvent) {
        let label = Self.label(for: event)
        guard !label.isEmpty else { return }
        onKeyDown?(label)
    }

    // MARK: - Étiquetage des touches

    /// Produit un libellé lisible et stable pour une frappe : le caractère
    /// imprimable lui-même, ou un libellé pour les touches spéciales.
    static func label(for event: NSEvent) -> String {
        if let special = specialKeyLabels[event.keyCode] {
            return special
        }
        // Caractère imprimable, indépendant des modificateurs (sauf Shift via
        // charactersIgnoringModifiers qui conserve la casse de base).
        if let chars = event.charactersIgnoringModifiers, let first = chars.first {
            if first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol {
                return String(first).lowercased()
            }
        }
        return ""
    }

    /// Libellés pour les touches non imprimables, indexés par `keyCode`.
    private static let specialKeyLabels: [UInt16: String] = [
        49:  "⎵ Espace",
        36:  "↩ Entrée",
        76:  "↩ Entrée",      // Enter du pavé numérique
        48:  "⇥ Tab",
        51:  "⌫ Retour arrière",
        117: "⌦ Suppr",
        53:  "⎋ Échap",
        123: "← Gauche",
        124: "→ Droite",
        125: "↓ Bas",
        126: "↑ Haut",
        115: "↖ Début",
        119: "↘ Fin",
        116: "⇞ Page haut",
        121: "⇟ Page bas"
    ]
}
