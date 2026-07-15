import Foundation

/// Client du classement en ligne — voir docs/LEADERBOARD.md.
///
/// Opt-in explicite : rien ne part tant que l'utilisateur n'a pas activé le
/// partage. Seuls les totaux du jour sont envoyés (frappes, distance, clics),
/// jamais le détail par touche. L'identité est un UUID aléatoire + un pseudo.
enum Leaderboard {
    /// URL de base du déploiement Vercel.
    static let baseURLString = "https://handometer.vercel.app"

    static var isConfigured: Bool { !baseURLString.isEmpty }

    enum Period: String, CaseIterable {
        case daily
        case weekly
    }

    // MARK: - Préférences (UserDefaults)

    private static let optInKey = "leaderboardOptIn"
    private static let nameKey = "leaderboardName"
    private static let clientIdKey = "leaderboardClientId"

    static var isOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: optInKey) }
        set { UserDefaults.standard.set(newValue, forKey: optInKey) }
    }

    static var displayName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    /// UUID anonyme, généré au premier accès puis stable.
    static var clientId: String {
        if let existing = UserDefaults.standard.string(forKey: clientIdKey) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: clientIdKey)
        return fresh
    }

    // MARK: - Modèles

    struct Entry: Decodable, Identifiable {
        let rank: Int
        let name: String
        let score: Int
        let isMe: Bool
        var id: Int { rank }
    }

    struct Standings: Decodable {
        let entries: [Entry]
        let me: MyRank?

        struct MyRank: Decodable {
            let rank: Int
            let score: Int
        }
    }

    // MARK: - Réseau

    private static var endpoint: URL? {
        URL(string: "\(baseURLString)/api/leaderboard")
    }

    /// Envoie les totaux du jour (fire-and-forget, silencieux en cas d'échec :
    /// la prochaine soumission écrase de toute façon).
    static func submit(today: DayStats) async {
        guard isConfigured, isOptedIn, let endpoint else { return }

        let payload: [String: Any] = [
            "clientId": clientId,
            "name": displayName,
            "dayKey": today.date,
            "keystrokes": today.totalKeystrokes,
            "distanceCm": today.mouseDistanceCm,
            "clicks": today.totalClicks
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        _ = try? await URLSession.shared.data(for: request)
    }

    static func fetchStandings(period: Period, dayKey: String) async throws -> Standings {
        guard isConfigured, let endpoint else {
            throw URLError(.badURL)
        }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "period", value: period.rawValue),
            URLQueryItem(name: "dayKey", value: dayKey),
            URLQueryItem(name: "clientId", value: isOptedIn ? clientId : nil)
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Standings.self, from: data)
    }
}
