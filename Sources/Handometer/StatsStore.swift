import Foundation

/// Persistance des statistiques sous `~/Library/Application Support/Handometer/`.
///
/// Deux fichiers, parce que seule la journée courante est mutée :
///   - `stats.json`  — l'archive complète (`[String: DayStats]`), réécrite
///     uniquement au changement de jour et à l'arrêt de l'app ;
///   - `today.json`  — la seule journée courante, réécrite sur le debounce.
///
/// Avant, chaque debounce ré-encodait tout l'historique : ~2 ms et 35 Ko à 41
/// jours, mais ça grossit linéairement (≈1 500 jours → ~1,3 Mo réécrits toutes
/// les 5 s d'activité). Le coût est maintenant celui d'une seule journée, quelle
/// que soit l'ancienneté de l'historique.
///
/// `days` n'est touché que sur le main actor. L'écriture débouncée part sur une
/// file dédiée, mais à partir d'un **snapshot pris sur le main actor** : lire
/// `days` depuis la file pendant que les événements le mutaient était une course.
@MainActor
final class StatsStore {
    private let archiveURL: URL
    private let todayURL: URL
    private static let ioQueue = DispatchQueue(label: "com.jeoste.macbookstats.store")
    private var saveWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 5

    /// Toutes les journées, indexées par clé `YYYY-MM-DD`.
    private(set) var days: [String: DayStats] = [:]

    /// Journée que les mutations touchent actuellement, donc celle qui part dans
    /// `today.json`. Quand elle change, l'archive doit être écrite avant.
    private var dirtyDayKey: String?

    /// `~/Library/Application Support/Handometer/`. `nonisolated` : une valeur
    /// par défaut d'argument est évaluée hors isolation d'acteur.
    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handometer", isDirectory: true)
    }

    /// `directory` est paramétrable pour que `Tools/selfcheck` puisse exercer la
    /// fusion au chargement sur un répertoire temporaire — cette logique décide
    /// si l'historique survit à un arrêt brutal, elle doit être vérifiable.
    init(directory: URL = StatsStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.archiveURL = directory.appendingPathComponent("stats.json")
        self.todayURL = directory.appendingPathComponent("today.json")
        load()
    }

    // MARK: - Lecture / écriture disque

    /// Charge l'archive, puis laisse `today.json` écraser sa journée : c'est lui
    /// qui est à jour si l'app a été tuée avant d'avoir réécrit l'archive.
    /// Les anciennes installations n'ont que `stats.json` — rien à migrer, la
    /// journée courante y est déjà et `today.json` apparaîtra à la 1re écriture.
    private func load() {
        if let data = try? Data(contentsOf: archiveURL),
           let decoded = try? JSONDecoder().decode([String: DayStats].self, from: data) {
            days = decoded
        }
        if let data = try? Data(contentsOf: todayURL),
           let day = try? JSONDecoder().decode(DayStats.self, from: data) {
            days[day.date] = day
            dirtyDayKey = day.date
        }
    }

    /// Planifie une sauvegarde débouncée. Un seul work item pendant à la fois :
    /// pas d'allocation par événement, et la sauvegarde part au plus tard
    /// `debounceInterval` après le premier événement (activité continue
    /// comprise — pas de report indéfini).
    func scheduleSave() {
        guard saveWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveDebounced() }
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Chemin débouncé : n'écrit que la journée courante, hors du main actor.
    private func saveDebounced() {
        saveWorkItem = nil
        guard let key = dirtyDayKey, let day = days[key] else { return }
        let url = todayURL
        Self.ioQueue.async { Self.write(day, to: url) }
    }

    /// Écriture immédiate **et synchrone** de l'archive : à l'arrêt de l'app et
    /// au changement de jour, on ne peut pas laisser une file terminer après nous.
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        writeArchive()
    }

    private func writeArchive() {
        Self.write(days, to: archiveURL)
        // L'archive contient désormais la journée : `today.json` ne sert plus
        // qu'à rattraper un arrêt brutal, il sera réécrit à la prochaine mutation.
        if let key = dirtyDayKey, let day = days[key] {
            Self.write(day, to: todayURL)
        }
    }

    private nonisolated static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            NSLog("Handometer: échec de sauvegarde (\(url.lastPathComponent)) — \(error)")
        }
    }

    // MARK: - Mutations
    //
    // Toutes en place via `days[dayKey, default:]` : passer par une copie
    // (`var d = stats(for:)` … `days[dayKey] = d`) déclenchait un copy-on-write
    // du dictionnaire `keyCounts` complet à chaque frappe.

    /// Récupère (ou crée) les stats d'un jour donné — lecture seule.
    func stats(for dayKey: String) -> DayStats {
        days[dayKey] ?? DayStats(date: dayKey)
    }

    /// Enregistre un segment de déplacement souris : distance (cm), durée du
    /// segment (s) et vitesse instantanée (km/h). Met à jour la distance
    /// cumulée, le temps de déplacement (pour la moyenne) et la vitesse max.
    func recordMovement(distanceCm: Double, seconds: Double, instantKmh: Double, to dayKey: String) {
        markDirty(dayKey)
        days[dayKey, default: DayStats(date: dayKey)]
            .addMovement(distanceCm: distanceCm, seconds: seconds, instantKmh: instantKmh)
    }

    /// Incrémente le compteur de clics du bouton indiqué pour le jour donné.
    func incrementClick(_ button: MouseButton, in dayKey: String) {
        markDirty(dayKey)
        switch button {
        case .left:   days[dayKey, default: DayStats(date: dayKey)].leftClicks += 1
        case .right:  days[dayKey, default: DayStats(date: dayKey)].rightClicks += 1
        case .middle: days[dayKey, default: DayStats(date: dayKey)].middleClicks += 1
        }
    }

    /// Incrémente le compteur d'une touche pour le jour indiqué.
    func incrementKey(_ key: String, in dayKey: String) {
        markDirty(dayKey)
        days[dayKey, default: DayStats(date: dayKey)].keyCounts[key, default: 0] += 1
    }

    /// La journée mutée change (minuit, ou relance après un arrêt brutal en
    /// pleine journée) : l'ancienne doit entrer dans l'archive avant que
    /// `today.json` ne soit écrasé, sinon elle n'existerait plus que en mémoire.
    private func markDirty(_ dayKey: String) {
        guard dirtyDayKey != dayKey else { return }
        if dirtyDayKey != nil { writeArchive() }
        dirtyDayKey = dayKey
    }
}
