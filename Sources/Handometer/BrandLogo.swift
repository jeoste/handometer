import AppKit
import SwiftUI

/// Logo officiel Handometer (curseur + wordmark). `build.sh` le bundle toujours.
enum BrandLogo {
    static let image: NSImage = {
        guard let url = Bundle.main.url(forResource: "brand-logo@2x", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return NSImage() }
        // Taille logique = pixels / 2 (rétine), quelle que soit la largeur
        // générée par Tools/genicon.swift.
        img.size = NSSize(width: img.size.width / 2, height: img.size.height / 2)
        return img
    }()
}

/// Affiche le logo officiel Handometer.
struct BrandLogoView: View {
    var height: CGFloat = 28

    var body: some View {
        Image(nsImage: BrandLogo.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
    }
}
