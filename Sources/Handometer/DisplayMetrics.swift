import AppKit
import CoreGraphics

/// Convertit des distances exprimées en pixels (coordonnées globales) en
/// centimètres physiques, en s'appuyant sur la taille réelle de l'écran
/// fournie par `CGDisplayScreenSize` (en millimètres).
final class DisplayMetrics {
    /// mm par pixel, mis en cache par identifiant d'écran.
    private var mmPerPixelCache: [CGDirectDisplayID: Double] = [:]

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        mmPerPixelCache.removeAll()
    }

    /// Convertit une distance pixel en cm pour l'écran situé sous `point`
    /// (coordonnées globales Cocoa, origine en bas à gauche de l'écran principal).
    func centimeters(forPixelDistance pixels: Double, near point: CGPoint) -> Double {
        let mmPerPixel = mmPerPixel(forDisplayContaining: point)
        return pixels * mmPerPixel / 10.0
    }

    /// Retourne les mm/pixel de l'écran contenant `point`, avec repli sur
    /// l'écran principal puis une valeur par défaut raisonnable.
    private func mmPerPixel(forDisplayContaining point: CGPoint) -> Double {
        let displayID = self.displayID(containing: point) ?? CGMainDisplayID()
        if let cached = mmPerPixelCache[displayID] {
            return cached
        }

        let sizeMM = CGDisplayScreenSize(displayID) // largeur/hauteur en mm
        let pixelsWide = Double(CGDisplayPixelsWide(displayID))

        let value: Double
        if sizeMM.width > 0 && pixelsWide > 0 {
            value = sizeMM.width / pixelsWide
        } else {
            // Repli : ~0.2495 mm/pixel ≈ 102 ppp (écran générique).
            value = 25.4 / 102.0
        }
        mmPerPixelCache[displayID] = value
        return value
    }

    /// Identifiant de l'écran contenant un point en coordonnées globales Cocoa.
    private func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        // CGGetDisplaysWithPoint attend des coordonnées avec l'origine en HAUT
        // à gauche ; NSEvent.mouseLocation utilise l'origine en BAS à gauche.
        // On convertit via la hauteur de l'écran principal.
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let flipped = CGPoint(x: point.x, y: primaryHeight - point.y)

        var displayID = CGDirectDisplayID()
        var count: UInt32 = 0
        let result = CGGetDisplaysWithPoint(flipped, 1, &displayID, &count)
        guard result == .success, count > 0 else { return nil }
        return displayID
    }
}
