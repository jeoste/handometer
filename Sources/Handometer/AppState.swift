import AppKit
import Combine

/// État observable central : relie le moniteur d'événements, le stockage et
/// l'interface SwiftUI.
@MainActor
final class AppState: ObservableObject {
    private let store = StatsStore()
    private let monitor = EventMonitor()
    private let metrics = DisplayMetrics()

    /// Clé du jour courant.
    @Published private(set) var currentDayKey: String = Date().dayKey
    /// Stats du jour courant (publiées pour l'UI).
    @Published private(set) var today: DayStats
    /// Historique trié par date croissante (pour les graphiques).
    @Published private(set) var history: [DayStats] = []

    /// État de la permission Accessibilité (TCC).
    @Published var isTrusted: Bool = Permissions.isTrusted
    /// Permission TCC accordée mais moniteur clavier inactif (souvent après une
    /// mise à jour avec signature ad-hoc différente).
    @Published private(set) var needsAccessibilityRegrant = false
    /// État du démarrage auto.
    @Published var launchAtLogin: Bool = LoginItem.isEnabled

    private var dayCheckTimer: Timer?
    private var permissionTimer: Timer?
    private var isRunning = false

    /// Horodatage du dernier événement souris, pour calculer la vitesse.
    private var lastMouseTimestamp: TimeInterval?
    /// Au-delà de cet écart entre deux événements, on considère que le
    /// déplacement a été interrompu (pas de calcul de vitesse).
    private let maxMovementGap: TimeInterval = 0.3
    /// Plancher du pas de temps, pour éviter des pics de vitesse irréalistes.
    private let minMovementDelta: TimeInterval = 0.008

    init() {
        let key = Date().dayKey
        self.today = store.stats(for: key)
        refreshHistory()
        configureMonitor()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        monitor.start()
        refreshPermissionState()

        let didUpdate = Permissions.consumeVersionChange()
        if didUpdate {
            restartEventMonitor()
        }
        recoverAccessibilityIfNeeded(afterUpdate: didUpdate)

        // Sauvegarde garantie à la fermeture de l'app.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }

        // Vérifie périodiquement le changement de jour et l'état des permissions.
        dayCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkDayRollover() }
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermissionState() }
        }
    }

    func stop() {
        monitor.stop()
        dayCheckTimer?.invalidate()
        permissionTimer?.invalidate()
        store.saveNow()
    }

    var storageURL: URL { store.storageURL }
    var allDays: [String: DayStats] { store.days }

    // MARK: - Configuration du moniteur

    private func configureMonitor() {
        monitor.onMouseMove = { [weak self] pixels, point, timestamp in
            Task { @MainActor in self?.recordMouse(pixels: pixels, point: point, timestamp: timestamp) }
        }
        monitor.onMouseClick = { [weak self] button in
            Task { @MainActor in self?.recordClick(button) }
        }
        monitor.onKeyDown = { [weak self] label in
            Task { @MainActor in self?.recordKey(label) }
        }
    }

    private func recordMouse(pixels: Double, point: CGPoint, timestamp: TimeInterval) {
        checkDayRollover()
        let cm = metrics.centimeters(forPixelDistance: pixels, near: point)

        var seconds = 0.0
        var instantKmh = 0.0
        if let last = lastMouseTimestamp {
            let dt = timestamp - last
            // On ne calcule la vitesse que pour des segments de mouvement
            // continu (écart raisonnable entre deux événements).
            if dt > 0 && dt <= maxMovementGap {
                seconds = dt
                let cmPerSecond = cm / max(dt, minMovementDelta)
                instantKmh = cmPerSecond * DayStats.cmPerSecondToKmh
            }
        }
        lastMouseTimestamp = timestamp

        store.recordMovement(distanceCm: cm, seconds: seconds, instantKmh: instantKmh, to: currentDayKey)
        today = store.stats(for: currentDayKey)
        store.scheduleSave()
    }

    private func recordClick(_ button: MouseButton) {
        checkDayRollover()
        store.incrementClick(button, in: currentDayKey)
        today = store.stats(for: currentDayKey)
        store.scheduleSave()
    }

    private func recordKey(_ label: String) {
        checkDayRollover()
        store.incrementKey(label, in: currentDayKey)
        today = store.stats(for: currentDayKey)
        store.scheduleSave()
    }

    // MARK: - Changement de jour

    private func checkDayRollover() {
        let key = Date().dayKey
        guard key != currentDayKey else { return }
        store.saveNow()
        currentDayKey = key
        today = store.stats(for: key)
        refreshHistory()
    }

    private func refreshHistory() {
        history = store.days.values.sorted { $0.date < $1.date }
    }

    // MARK: - Actions UI

    func toggleLaunchAtLogin() {
        launchAtLogin = LoginItem.setEnabled(!launchAtLogin)
    }

    func requestPermission() {
        Permissions.requestIfNeeded()
        restartEventMonitor()
        recoverAccessibilityIfNeeded(afterUpdate: false)
    }

    func openPermissionSettings() {
        Permissions.openSettings()
    }

    // MARK: - Accessibilité (post-mise à jour)

    private func refreshPermissionState() {
        isTrusted = Permissions.isTrusted
        needsAccessibilityRegrant = isTrusted && !monitor.isGlobalKeyMonitorActive
    }

    private func pollPermissionState() {
        let wasTrusted = isTrusted
        let wasKeyActive = monitor.isGlobalKeyMonitorActive
        refreshPermissionState()

        if isTrusted != wasTrusted || isTrusted && monitor.isGlobalKeyMonitorActive != wasKeyActive {
            restartEventMonitor()
        }
        if needsAccessibilityRegrant {
            recoverAccessibilityIfNeeded(afterUpdate: false)
        }
    }

    private func restartEventMonitor() {
        guard isRunning else { return }
        monitor.stop()
        monitor.start()
        refreshPermissionState()
    }

    private func recoverAccessibilityIfNeeded(afterUpdate: Bool) {
        guard needsAccessibilityRegrant else { return }
        Permissions.promptRegrantIfNeeded(afterUpdate: afterUpdate)
    }

    func refresh() {
        today = store.stats(for: currentDayKey)
        refreshHistory()
    }
}
