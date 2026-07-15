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
        case allTime = "alltime"
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
        let trophies: Int
        let isMe: Bool
        var id: Int { rank }
    }

    /// Trophée de podium (top 3 d'une période close du classement).
    struct Trophy: Decodable, Identifiable {
        let id: String          // « day:2026-07-15 », « week:2026-W29 », …
        let period: String      // day | week | month | quarter | year
        let periodKey: String
        let rank: Int
        let xp: Int
        let score: Int
    }

    struct TrophyCollection: Decodable {
        let trophies: [Trophy]
        let totalXp: Int
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

    /// Envoie les totaux du jour et l'XP lifetime (fire-and-forget, silencieux
    /// en cas d'échec : la prochaine soumission écrase de toute façon).
    /// `lifetimeXP` alimente le classement all-time : c'est la même valeur que
    /// le niveau local (historique complet + bonus), pas un cumul serveur.
    static func submit(today: DayStats, lifetimeXP: Double) async {
        guard isConfigured, isOptedIn, let endpoint else { return }

        let payload: [String: Any] = [
            "clientId": clientId,
            "name": displayName,
            "dayKey": today.date,
            "keystrokes": today.totalKeystrokes,
            "distanceCm": today.mouseDistanceCm,
            "clicks": today.totalClicks,
            "lifetimeXp": Int(lifetimeXP)
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        _ = try? await URLSession.shared.data(for: request)
    }

    /// Dernier total d'XP de trophées connu, persisté pour que le niveau reste
    /// stable hors-ligne (rafraîchi à chaque fetch de la collection).
    /// Cache mémoire : `trophyXP` est lu à chaque calcul de `playerLevel`
    /// (plusieurs fois par seconde) — pas d'accès UserDefaults sur ce chemin.
    private static let trophyXPKey = "leaderboardTrophyXP"
    private static var cachedTrophyXP = UserDefaults.standard.integer(forKey: trophyXPKey)

    static var trophyXP: Int { cachedTrophyXP }

    /// Récupère la collection de trophées et met en cache son total d'XP.
    static func fetchTrophies() async throws -> TrophyCollection {
        guard isConfigured, isOptedIn,
              let url = URL(string: "\(baseURLString)/api/trophies?clientId=\(clientId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let collection = try JSONDecoder().decode(TrophyCollection.self, from: data)
        cachedTrophyXP = collection.totalXp
        UserDefaults.standard.set(collection.totalXp, forKey: trophyXPKey)
        return collection
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
