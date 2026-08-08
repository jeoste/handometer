// Contrôles du chemin chaud et de la persistance en deux fichiers.
// Pas de framework — la machine de dev n'a que les Command Line Tools, donc
// pas de XCTest. Lancer :
//
//     bash Tools/selfcheck.sh
//
// `StatsStore` est construit sur un répertoire **temporaire** : jamais sur
// `~/Library/Application Support/Handometer/`, où vivent les vraies données.

import Foundation

var failures = 0

func check(_ condition: Bool, _ what: String) {
    if condition {
        print("  ok   \(what)")
    } else {
        print("  FAIL \(what)")
        failures += 1
    }
}

// MARK: - Borne de jour (remplace le formatage par événement)

print("Date.nextMidnight")

// Le piège attrapé ici : `startOfDay + 86 400`. Les jours de changement d'heure
// font 23 ou 25 h, donc ce calcul ne tombe pas sur minuit et la borne dérive
// d'une heure à chaque transition. On balaie 400 jours pour couvrir les deux
// transitions de l'année, quel que soit le fuseau de la machine.
let calendar = Calendar.current
var alwaysFuture = true
var alwaysMidnight = true
var neverSkipsADay = true

for offsetDays in 0..<400 {
    let from = Date().addingTimeInterval(Double(offsetDays) * 86_400)
    let next = from.nextMidnight

    if next <= from { alwaysFuture = false }
    if next != calendar.startOfDay(for: next) { alwaysMidnight = false }
    if next.timeIntervalSince(from) > 25 * 3_600 { neverSkipsADay = false }
}

check(alwaysFuture, "la borne est toujours dans le futur")
check(alwaysMidnight, "la borne tombe toujours exactement sur minuit local")
check(neverSkipsADay, "la borne ne saute jamais un jour (≤ 25 h, jour long DST compris)")

let now = Date()
check(
    !calendar.isDate(now.nextMidnight, inSameDayAs: now),
    "minuit suivant appartient bien au jour d'après"
)

// MARK: - Mutations en place

print("DayStats.addMovement")

var day = DayStats(date: "2026-08-08")
day.addMovement(distanceCm: 10, seconds: 0.5, instantKmh: 4)
day.addMovement(distanceCm: 5, seconds: 0.25, instantKmh: 9)
day.addMovement(distanceCm: 2, seconds: 0.10, instantKmh: 3)

check(abs(day.mouseDistanceCm - 17) < 1e-9, "la distance se cumule")
check(abs(day.movementSeconds - 0.85) < 1e-9, "le temps de déplacement se cumule")
check(abs(day.maxSpeedKmh - 9) < 1e-9, "la vitesse est un maximum, pas la dernière valeur")

// Un segment sans durée (écart trop grand entre deux événements) ne doit pas
// polluer le dénominateur de la vitesse moyenne.
var gap = DayStats(date: "2026-08-08")
gap.addMovement(distanceCm: 3, seconds: 0, instantKmh: 0)
check(abs(gap.mouseDistanceCm - 3) < 1e-9, "un segment sans durée compte quand même en distance")
check(gap.movementSeconds == 0, "un segment sans durée n'ajoute pas de temps")

print("days[key, default:] — création puis mutation en place")

var days: [String: DayStats] = [:]
let key = "2026-08-08"
for _ in 0..<3 {
    days[key, default: DayStats(date: key)].keyCounts["a", default: 0] += 1
}
days[key, default: DayStats(date: key)].keyCounts["b", default: 0] += 1
days[key, default: DayStats(date: key)].leftClicks += 1

check(days.count == 1, "une seule journée créée")
check(days[key]?.date == key, "le défaut porte la bonne clé de jour")
check(days[key]?.keyCounts["a"] == 3, "la même touche s'incrémente")
check(days[key]?.keyCounts["b"] == 1, "une touche neuve s'ajoute")
check(days[key]?.totalKeystrokes == 4, "le total de frappes suit")
check(days[key]?.leftClicks == 1, "les clics s'incrémentent aussi en place")

// L'hypothèse qui rend la sauvegarde hors du main actor sûre : le snapshot est
// une valeur, il ne voit pas les mutations postérieures.
print("snapshot immuable (sauvegarde hors du main actor)")

var live: [String: DayStats] = ["d": DayStats(date: "d", keyCounts: ["a": 1])]
let snapshot = live
live["d", default: DayStats(date: "d")].keyCounts["a", default: 0] += 41

check(snapshot["d"]?.keyCounts["a"] == 1, "le snapshot ne suit pas les mutations")
check(live["d"]?.keyCounts["a"] == 42, "la valeur vivante a bien été mutée")

// MARK: - Persistance en deux fichiers (archive + jour courant)

// Chaque scénario part d'un répertoire temporaire neuf. Ce qui est en jeu :
// aucun jour ne doit disparaître, quel que soit le moment de l'arrêt.
func withTempStore(_ body: (URL) -> Void) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("handometer-selfcheck-\(UUID().uuidString)")
    body(dir)
    try? FileManager.default.removeItem(at: dir)
}

func writeJSON<T: Encodable>(_ value: T, to url: URL) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try? encoder.encode(value).write(to: url, options: .atomic)
}

MainActor.assumeIsolated {
    print("StatsStore — installation neuve")
    withTempStore { dir in
        let store = StatsStore(directory: dir)
        check(store.days.isEmpty, "aucune journée au départ")
        store.incrementKey("a", in: "2026-08-09")
        store.saveNow()
        let reloaded = StatsStore(directory: dir)
        check(reloaded.days["2026-08-09"]?.keyCounts["a"] == 1, "la journée survit à un rechargement")
    }

    // Le cas de tous les utilisateurs actuels : un stats.json, pas de today.json.
    print("StatsStore — migration depuis stats.json seul")
    withTempStore { dir in
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let archive: [String: DayStats] = [
            "2026-08-07": DayStats(date: "2026-08-07", keyCounts: ["x": 100]),
            "2026-08-08": DayStats(date: "2026-08-08", keyCounts: ["y": 200])
        ]
        writeJSON(archive, to: dir.appendingPathComponent("stats.json"))

        let store = StatsStore(directory: dir)
        check(store.days.count == 2, "l'archive existante est chargée telle quelle")
        check(store.days["2026-08-07"]?.keyCounts["x"] == 100, "les jours passés sont intacts")
        check(store.days["2026-08-08"]?.keyCounts["y"] == 200, "le jour courant de l'archive est intact")
    }

    // Arrêt brutal en pleine journée : l'archive est en retard, today.json à jour.
    print("StatsStore — arrêt brutal, today.json rattrape l'archive")
    withTempStore { dir in
        let store = StatsStore(directory: dir)
        store.incrementKey("a", in: "2026-08-09")
        store.saveNow()                      // archive + today.json à 1 frappe
        for _ in 0..<9 { store.incrementKey("a", in: "2026-08-09") }
        writeJSON(store.stats(for: "2026-08-09"), to: dir.appendingPathComponent("today.json"))
        // Pas de saveNow() : l'archive reste à 1, comme après un SIGKILL.

        let reloaded = StatsStore(directory: dir)
        check(
            reloaded.days["2026-08-09"]?.keyCounts["a"] == 10,
            "today.json gagne sur la copie périmée de l'archive"
        )
    }

    // Relance le lendemain après un arrêt brutal : la journée qui n'existait que
    // dans today.json doit entrer dans l'archive avant d'être écrasée.
    print("StatsStore — changement de jour, la veille entre dans l'archive")
    withTempStore { dir in
        let store = StatsStore(directory: dir)
        store.incrementKey("a", in: "2026-08-08")
        writeJSON(store.stats(for: "2026-08-08"), to: dir.appendingPathComponent("today.json"))
        writeJSON([String: DayStats](), to: dir.appendingPathComponent("stats.json"))

        // Relance : la veille n'est que dans today.json.
        let next = StatsStore(directory: dir)
        check(next.days["2026-08-08"]?.keyCounts["a"] == 1, "la veille est récupérée depuis today.json")

        // Première frappe du nouveau jour : doit flusher la veille dans l'archive.
        next.incrementKey("b", in: "2026-08-09")

        let archiveData = try? Data(contentsOf: dir.appendingPathComponent("stats.json"))
        let archive = archiveData.flatMap { try? JSONDecoder().decode([String: DayStats].self, from: $0) }
        check(
            archive?["2026-08-08"]?.keyCounts["a"] == 1,
            "la veille est dans l'archive dès que le jour courant change"
        )

        // Et rien n'est perdu au rechargement suivant.
        next.saveNow()
        let third = StatsStore(directory: dir)
        check(third.days.count == 2, "les deux journées sont là")
        check(third.days["2026-08-09"]?.keyCounts["b"] == 1, "le nouveau jour aussi")
    }

    print("StatsStore — le debounce n'écrit que le jour courant")
    withTempStore { dir in
        let store = StatsStore(directory: dir)
        store.incrementKey("a", in: "2026-08-09")
        store.saveNow()
        let archiveSize = (try? Data(contentsOf: dir.appendingPathComponent("stats.json")))?.count ?? 0
        let todaySize = (try? Data(contentsOf: dir.appendingPathComponent("today.json")))?.count ?? 0
        check(todaySize > 0, "today.json est écrit")
        check(todaySize < archiveSize, "le fichier du jour est plus petit que l'archive")
    }
}

// MARK: -

print("")
if failures == 0 {
    print("✓ tous les contrôles passent")
} else {
    print("✗ \(failures) contrôle(s) en échec")
    exit(1)
}
