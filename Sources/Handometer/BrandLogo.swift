import AppKit
import SwiftUI

/// Logo officiel Handometer (curseur + wordmark), bundlé dans l'app.
enum BrandLogo {
    static let image: NSImage = {
        if let url = Bundle.main.url(forResource: "brand-logo@2x", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            // Taille logique = pixels / 2 (rétine), quelle que soit la largeur
            // générée par Tools/genicon.swift.
            img.size = NSSize(width: img.size.width / 2, height: img.size.height / 2)
            return img
        }
        if let url = Bundle.main.url(forResource: "brand-logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage()
    }()
}

/// Affiche le logo officiel Handometer, avec repli sur le wordmark texte si absent.
struct BrandLogoView: View {
    var height: CGFloat = 28
    /// Opacité appliquée au repli texte uniquement ; le PNG officiel inclut déjà la teinte.
    var fallbackOpacity: Double = 0.4

    var body: some View {
        if BrandLogo.image.size.width > 0 {
            Image(nsImage: BrandLogo.image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: height * 0.64, weight: .bold))
                Text("Handometer")
                    .font(.system(size: height * 0.78, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(fallbackOpacity))
        }
    }
}
