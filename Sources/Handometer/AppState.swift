import AppKit
import Combine

/// État observable central : relie le moniteur d'événements, le stockage et
/// l'interface SwiftUI.
@MainActor
final class AppState: ObservableObject {
    private let store = StatsStore()
    private let achievementStore = AchievementStore()
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
    /// Souris globale active mais pas le clavier : permission TCC obsolète ou
    /// binaire différent de celui autorisé (rebuild ad-hoc, copie multiple).
    @Published private(set) var needsAccessibilityRegrant = false
    /// État du démarrage auto.
    @Published var launchAtLogin: Bool = LoginItem.isEnabled
    /// Achievements débloqués (tous scopes).
    @Published private(set) var achievements: [UnlockedAchievement] = []
    /// Compteurs de touches cumulés sur toutes les journées.
    /// Cache incrémental : mis à jour à chaque frappe, reconstruit quand
    /// l'historique est rechargé (évite un merge complet à chaque accès).
    private(set) var globalKeyCounts: [String: Int] = [:]
    /// Dernier unlock en attente d'affichage (bannière / preview).
    @Published var pendingUnlock: UnlockedAchievement?

    private var dayCheckTimer: Timer?
    private var bannerDismissWorkItem: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var leaderboardTimer: Timer?
    private var uiSyncWorkItem: DispatchWorkItem?
    private var isRunning = false

    /// Intervalle minimum entre deux rafraîchissements UI (souris, clics et
    /// frappes). Les événements sont toujours enregistrés ; seule la
    /// publication SwiftUI est limitée pour éviter des centaines de re-rendus
    /// et d'évaluations d'achievements par seconde.
    private let uiSyncInterval: TimeInterval = 0.5

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
        syncAchievementsFromStore()
        _ = achievementStore.retroactiveScan(
            history: history,
            globalKeyCounts: globalKeyCounts,
            currentDayKey: key
        )
        syncAchievementsFromStore()
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
        // Soumission périodique au classement (no-op si non configuré / opt-out).
        leaderboardTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let today = self.store.stats(for: self.currentDayKey)
                Task { await Leaderboard.submit(today: today) }
            }
        }
    }

    func stop() {
        monitor.stop()
        dayCheckTimer?.invalidate()
        permissionTimer?.invalidate()
        leaderboardTimer?.invalidate()
        flushUISync()
        store.saveNow()
        achievementStore.saveNow()
    }

    var storageURL: URL { store.storageURL }
    var allDays: [String: DayStats] { store.days }

    /// Nombre total de frappes sur toutes les journées enregistrées.
    var totalKeystrokes: Int { history.totalKeystrokes }

    /// Niveau de progression, dérivé des stats cumulées + bonus d'achievements.
    var playerLevel: PlayerLevel {
        let base = Double(history.totalKeystrokes) * PlayerLevel.xpPerKeystroke
            + history.totalMouseDistanceCm * PlayerLevel.xpPerCm
            + Double(history.totalClicks) * PlayerLevel.xpPerClick
        let bonus = achievements.reduce(0.0) { $0 + $1.definition.tier.xpBonus }
        return PlayerLevel(lifetimeXP: base + bonus)
    }

    // MARK: - Configuration du moniteur

    private func configureMonitor() {
        // Les moniteurs NSEvent sont livrés sur la file principale ; pas de Task
        // par événement (sinon accumulation mémoire à ~100 Hz).
        monitor.onMouseMove = { [weak self] pixels, point, timestamp in
            MainActor.assumeIsolated {
                self?.recordMouse(pixels: pixels, point: point, timestamp: timestamp)
            }
        }
        monitor.onMouseClick = { [weak self] button in
            MainActor.assumeIsolated { self?.recordClick(button) }
        }
        monitor.onKeyDown = { [weak self] label in
            MainActor.assumeIsolated { self?.recordKey(label) }
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
        scheduleUISync()
        store.scheduleSave()
    }

    private func recordClick(_ button: MouseButton) {
        checkDayRollover()
        store.incrementClick(button, in: currentDayKey)
        scheduleUISync()
        store.scheduleSave()
    }

    private func recordKey(_ label: String) {
        checkDayRollover()
        store.incrementKey(label, in: currentDayKey)
        globalKeyCounts[label, default: 0] += 1
        scheduleUISync()
        store.scheduleSave()
    }

    /// Planifie une synchro UI débouncée (mouvements souris à haute fréquence).
    private func scheduleUISync() {
        guard uiSyncWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.uiSyncWorkItem = nil
            self.syncPublishedStats()
        }
        uiSyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + uiSyncInterval, execute: work)
    }

    /// Force une synchro UI immédiate (arrêt, changement de jour, etc.).
    private func flushUISync() {
        uiSyncWorkItem?.cancel()
        uiSyncWorkItem = nil
        syncPublishedStats()
    }

    private func syncPublishedStats() {
        today = store.stats(for: currentDayKey)
        refreshHistory()
        evaluateAchievements()
    }

    private func syncAchievementsFromStore() {
        achievements = achievementStore.unlocks.sorted { $0.unlockedAt > $1.unlockedAt }
    }

    func achievements(for scope: AchievementScope) -> [UnlockedAchievement] {
        achievementStore.unlocks(for: scope, dayKey: currentDayKey)
    }

    func dismissPendingUnlock() {
        bannerDismissWorkItem?.cancel()
        pendingUnlock = nil
    }

    private func evaluateAchievements() {
        let newUnlocks = AchievementEvaluator.evaluate(
            today: today,
            history: history,
            globalKeyCounts: globalKeyCounts,
            alreadyUnlockedKeys: achievementStore.unlockedKeys,
            currentDayKey: currentDayKey
        )
        let added = achievementStore.add(newUnlocks, dayKey: currentDayKey)
        guard !added.isEmpty else { return }

        syncAchievementsFromStore()

        for unlock in added {
            AchievementNotifier.notify(unlock: unlock)
        }

        if let latest = added.last {
            pendingUnlock = latest
            scheduleBannerDismiss()
        }
    }

    private func scheduleBannerDismiss() {
        bannerDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingUnlock = nil
        }
        bannerDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
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
        let todayStats = store.stats(for: currentDayKey)
        if let index = history.firstIndex(where: { $0.date == currentDayKey }) {
            guard history[index] != todayStats else { return }
            history[index] = todayStats
        } else {
            history = store.days.values.sorted { $0.date < $1.date }
            globalKeyCounts = history.aggregatedKeyCounts
        }
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

    /// Supprime l'entrée TCC puis rouvre les Réglages pour que l'utilisateur
    /// puisse réaccorder la permission.
    func resetAccessibilityPermission() {
        switch Permissions.resetAccessibilityEntry() {
        case .success:
            finishAccessibilityReset()
        case .cancelled:
            break
        case .failed(let message):
            Permissions.showResetFailure(message)
        }
    }

    // MARK: - Accessibilité (post-mise à jour)

    private func refreshPermissionState() {
        isTrusted = Permissions.isTrusted
        // Souris globale OK mais pas le clavier : permission TCC fantôme
        // (souvent après déplacement, rebuild ad-hoc, ou copie multiple).
        needsAccessibilityRegrant = monitor.isGlobalMouseMonitorActive
            && !monitor.isGlobalKeyMonitorActive
    }

    private func pollPermissionState() {
        let wasTrusted = isTrusted
        let wasKeyActive = monitor.isGlobalKeyMonitorActive
        refreshPermissionState()

        if isTrusted != wasTrusted || isTrusted && monitor.isGlobalKeyMonitorActive != wasKeyActive {
            restartEventMonitor()
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
        guard Permissions.offerAccessibilityReset(afterUpdate: afterUpdate) else { return }
        resetAccessibilityPermission()
    }

    private func finishAccessibilityReset() {
        refreshPermissionState()
        Permissions.requestIfNeeded()
        Permissions.openSettings()
        restartEventMonitor()
        refreshPermissionState()
    }

    func refresh() {
        today = store.stats(for: currentDayKey)
        refreshHistory()
    }
}
