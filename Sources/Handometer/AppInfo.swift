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

    /// Ex. « Version 1.0.2 (42) »
    static var versionLine: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    /// Ex. « Built 22 Jun 2026 at 18:39 »
    static var builtLine: String? {
        guard let buildDate else { return nil }
        return "Built \(buildDate)"
    }
}
