import AppKit
import SwiftUI

@MainActor
enum AchievementSharer {
    static let cardSize = CGSize(width: 1200, height: 675)

    static func renderImage(for unlock: UnlockedAchievement) -> NSImage? {
        let view = AchievementCardView(unlock: unlock, forShare: true)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(cardSize)
        renderer.scale = 2
        return renderer.nsImage
    }

    static func shareOnX(unlock: UnlockedAchievement) {
        guard let image = renderImage(for: unlock) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        let text = unlock.shareText()
        let tweetService = NSSharingService(named: NSSharingService.Name("com.apple.share.Twitter.post"))
            ?? NSSharingService(named: NSSharingService.Name("com.apple.share.Twitter.compose"))
        if let tweetService {
            tweetService.perform(withItems: [text, image])
            return
        }

        if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://x.com/intent/tweet?text=\(encoded)") {
            NSWorkspace.shared.open(url)
        }

        let alert = NSAlert()
        alert.messageText = "Image copied to clipboard"
        alert.informativeText = "Paste the image into your post on X."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
