import AppKit

/// Bouton de souris cliqué.
enum MouseButton {
    case left
    case right
    case middle
}

/// Surveille globalement les mouvements de souris, les clics et les frappes
/// clavier.
///
/// Utilise à la fois un *global monitor* (événements destinés aux autres apps)
/// et un *local monitor* (événements destinés à notre propre app) afin de ne
/// rien manquer. La capture du clavier nécessite la permission Accessibilité.
final class EventMonitor {
    private var globalMonitors: [Any] = []
    private var localMonitor: Any?

    /// Appelé pour chaque segment de déplacement souris :
    /// (distance px, point global, horodatage en secondes).
    var onMouseMove: ((Double, CGPoint, TimeInterval) -> Void)?
    /// Appelé pour chaque clic souris : bouton concerné.
    var onMouseClick: ((MouseButton) -> Void)?
    /// Appelé pour chaque frappe : libellé de la touche.
    var onKeyDown: ((String) -> Void)?

    /// Indique si le moniteur global souris est actif (ne nécessite pas
    /// Accessibilité).
    private(set) var isGlobalMouseMonitorActive = false
    /// Indique si le moniteur global clavier est actif (preuve que la permission
    /// Accessibilité fonctionne réellement, pas seulement selon TCC).
    private(set) var isGlobalKeyMonitorActive = false

    private let mouseMask: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]
    private let clickMask: NSEvent.EventTypeMask = [
        .leftMouseDown, .rightMouseDown, .otherMouseDown
    ]
    private let keyMask: NSEvent.EventTypeMask = [.keyDown]

    func start() {
        stop()
        let allMask = mouseMask.union(clickMask).union(keyMask)

        // Global : événements des autres applications.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] in
            self?.handleMouse($0)
        }) {
            globalMonitors.append(m)
            isGlobalMouseMonitorActive = true
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: clickMask, handler: { [weak self] in
            self?.handleClick($0)
        }) {
            globalMonitors.append(m)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: keyMask, handler: { [weak self] in
            self?.handleKey($0)
        }) {
            globalMonitors.append(m)
            isGlobalKeyMonitorActive = true
        }

        // Local : événements destinés à notre propre fenêtre (dashboard ouvert).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: allMask) { [weak self] event in
            guard let self else { return event }
            let type = NSEvent.EventTypeMask(type: event.type)
            if self.mouseMask.contains(type) {
                self.handleMouse(event)
            } else if self.clickMask.contains(type) {
                self.handleClick(event)
            } else if event.type == .keyDown {
                self.handleKey(event)
            }
            return event
        }
    }

    func stop() {
        for m in globalMonitors { NSEvent.removeMonitor(m) }
        globalMonitors.removeAll()
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
        isGlobalMouseMonitorActive = false
        isGlobalKeyMonitorActive = false
    }

    // MARK: - Handlers

    private func handleMouse(_ event: NSEvent) {
        let dx = event.deltaX
        let dy = event.deltaY
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0 else { return }
        onMouseMove?(distance, NSEvent.mouseLocation, event.timestamp)
    }

    private func handleClick(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            onMouseClick?(.left)
        case .rightMouseDown:
            onMouseClick?(.right)
        case .otherMouseDown:
            // Bouton 2 = molette (clic central). Les autres boutons auxiliaires
            // (précédent/suivant…) sont ignorés.
            if event.buttonNumber == 2 {
                onMouseClick?(.middle)
            }
        default:
            break
        }
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
        49:  "⎵ Space",
        36:  "↩ Enter",
        76:  "↩ Enter",       // Enter du pavé numérique
        48:  "⇥ Tab",
        51:  "⌫ Backspace",
        117: "⌦ Delete",
        53:  "⎋ Esc",
        123: "← Left",
        124: "→ Right",
        125: "↓ Down",
        126: "↑ Up",
        115: "↖ Home",
        119: "↘ End",
        116: "⇞ Page Up",
        121: "⇟ Page Down"
    ]
}
