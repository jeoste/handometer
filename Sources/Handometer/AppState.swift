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

    /// État de la permission Accessibilité.
    @Published var isTrusted: Bool = Permissions.isTrusted
    /// État du démarrage auto.
    @Published var launchAtLogin: Bool = LoginItem.isEnabled

    private var dayCheckTimer: Timer?
    private var permissionTimer: Timer?
    private var isRunning = false

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
            Task { @MainActor in self?.checkDayRollover() }
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.isTrusted = Permissions.isTrusted }
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
        monitor.onMouseMove = { [weak self] pixels, point in
            Task { @MainActor in self?.recordMouse(pixels: pixels, point: point) }
        }
        monitor.onKeyDown = { [weak self] label in
            Task { @MainActor in self?.recordKey(label) }
        }
    }

    private func recordMouse(pixels: Double, point: CGPoint) {
        checkDayRollover()
        let cm = metrics.centimeters(forPixelDistance: pixels, near: point)
        store.addDistance(cm, to: currentDayKey)
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
        isTrusted = Permissions.isTrusted
    }

    func openPermissionSettings() {
        Permissions.openSettings()
    }

    func refresh() {
        today = store.stats(for: currentDayKey)
        refreshHistory()
    }
}
