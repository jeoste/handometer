import Foundation

/// Statistiques agrégées pour un jour donné.
///
/// Pour des raisons de vie privée, on ne stocke que des **compteurs par
/// caractère** (`keyCounts`) et jamais l'ordre des frappes ni les mots tapés.
struct DayStats: Codable, Equatable {
    /// Date au format `YYYY-MM-DD`.
    var date: String
    /// Distance physique parcourue par le curseur, en centimètres.
    var mouseDistanceCm: Double
    /// Nombre de frappes par caractère/touche (clé = caractère ou libellé de
    /// touche spéciale comme "⎵ Space").
    var keyCounts: [String: Int]

    /// Vitesse maximale instantanée observée dans la journée, en km/h.
    var maxSpeedKmh: Double
    /// Temps cumulé pendant lequel la souris se déplaçait réellement, en
    /// secondes (dénominateur de la vitesse moyenne).
    var movementSeconds: Double

    /// Nombre de clics gauches.
    var leftClicks: Int
    /// Nombre de clics droits.
    var rightClicks: Int
    /// Nombre de clics molette (bouton central).
    var middleClicks: Int

    init(date: String,
         mouseDistanceCm: Double = 0,
         keyCounts: [String: Int] = [:],
         maxSpeedKmh: Double = 0,
         movementSeconds: Double = 0,
         leftClicks: Int = 0,
         rightClicks: Int = 0,
         middleClicks: Int = 0) {
        self.date = date
        self.mouseDistanceCm = mouseDistanceCm
        self.keyCounts = keyCounts
        self.maxSpeedKmh = maxSpeedKmh
        self.movementSeconds = movementSeconds
        self.leftClicks = leftClicks
        self.rightClicks = rightClicks
        self.middleClicks = middleClicks
    }

    /// Nombre total de frappes du jour.
    var totalKeystrokes: Int {
        keyCounts.values.reduce(0, +)
    }

    /// Fusionne les compteurs de touches de plusieurs journées.
    static func aggregatedKeyCounts(from days: some Collection<DayStats>) -> [String: Int] {
        var merged: [String: Int] = [:]
        for day in days {
            for (key, count) in day.keyCounts {
                merged[key, default: 0] += count
            }
        }
        return merged
    }

    /// Nombre total de clics (gauche + droit + molette).
    var totalClicks: Int {
        leftClicks + rightClicks + middleClicks
    }

    /// Vitesse moyenne de déplacement de la souris, en km/h.
    var averageSpeedKmh: Double {
        guard movementSeconds > 0 else { return 0 }
        let cmPerSecond = mouseDistanceCm / movementSeconds
        return cmPerSecond * Self.cmPerSecondToKmh
    }

    /// Facteur de conversion : 1 cm/s = 0,036 km/h.
    static let cmPerSecondToKmh = 0.036

    // MARK: - Décodage rétro-compatible

    private enum CodingKeys: String, CodingKey {
        case date, mouseDistanceCm, keyCounts
        case maxSpeedKmh, movementSeconds
        case leftClicks, rightClicks, middleClicks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        mouseDistanceCm = try c.decodeIfPresent(Double.self, forKey: .mouseDistanceCm) ?? 0
        keyCounts = try c.decodeIfPresent([String: Int].self, forKey: .keyCounts) ?? [:]
        // Champs ajoutés après la v1 : absents des anciens fichiers JSON.
        maxSpeedKmh = try c.decodeIfPresent(Double.self, forKey: .maxSpeedKmh) ?? 0
        movementSeconds = try c.decodeIfPresent(Double.self, forKey: .movementSeconds) ?? 0
        leftClicks = try c.decodeIfPresent(Int.self, forKey: .leftClicks) ?? 0
        rightClicks = try c.decodeIfPresent(Int.self, forKey: .rightClicks) ?? 0
        middleClicks = try c.decodeIfPresent(Int.self, forKey: .middleClicks) ?? 0
    }
}

extension Collection where Element == DayStats {
    /// Nombre total de frappes sur toutes les journées.
    var totalKeystrokes: Int {
        reduce(0) { $0 + $1.totalKeystrokes }
    }

    /// Compteurs de touches cumulés sur toutes les journées.
    var aggregatedKeyCounts: [String: Int] {
        DayStats.aggregatedKeyCounts(from: self)
    }

    /// Nombre total de clics sur toutes les journées.
    var totalClicks: Int {
        reduce(0) { $0 + $1.totalClicks }
    }

    /// Distance souris cumulée, en centimètres.
    var totalMouseDistanceCm: Double {
        reduce(0) { $0 + $1.mouseDistanceCm }
    }
}

extension DateFormatter {
    /// Formateur partagé pour les clés de jour (`YYYY-MM-DD`), en heure locale.
    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Affichage lisible d'une date (ex. « Wed, Jul 1, 2026 »).
    static let dayDisplay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .current
        f.timeZone = .current
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Libellé court pour les axes de graphiques (ex. « Jun 30 »).
    static let chartAxis: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .current
        f.timeZone = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()
}

extension Date {
    /// Clé de jour `YYYY-MM-DD` correspondant à cette date en heure locale.
    var dayKey: String {
        DateFormatter.dayKey.string(from: self)
    }
}
