import Foundation

/// Métadonnées de version injectées dans l'`Info.plist` par `build.sh`.
enum AppInfo {
    static let githubURL = URL(string: "https://github.com/jeoste/handometer")!

    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var buildDate: String? {
        let raw = Bundle.main.infoDictionary?["HMBuildDate"] as? String
        return raw?.isEmpty == false ? raw : nil
    }
}
