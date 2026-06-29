import Foundation

/// Statistiques agrégées pour un jour donné.
///
/// Pour des raisons de vie privée, on ne stocke que des **compteurs par
/// caractère** (`keyCounts`) et jamais l'ordre des frappes ni les mots tapés.
struct DayStats: Codable {
    /// Date au format `YYYY-MM-DD`.
    var date: String
    /// Distance physique parcourue par le curseur, en centimètres.
    var mouseDistanceCm: Double
    /// Nombre de frappes par caractère/touche (clé = caractère ou libellé de
    /// touche spéciale comme "⎵ Espace").
    var keyCounts: [String: Int]

    init(date: String, mouseDistanceCm: Double = 0, keyCounts: [String: Int] = [:]) {
        self.date = date
        self.mouseDistanceCm = mouseDistanceCm
        self.keyCounts = keyCounts
    }

    /// Nombre total de frappes du jour.
    var totalKeystrokes: Int {
        keyCounts.values.reduce(0, +)
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
}

extension Date {
    /// Clé de jour `YYYY-MM-DD` correspondant à cette date en heure locale.
    var dayKey: String {
        DateFormatter.dayKey.string(from: self)
    }
}
