import AppKit
import Combine

/// État observable central : relie le moniteur d'événements, le stockage et
/// l'interface SwiftUI.
///
/// Les stats sont **toujours** enregistrées. Les publications `@Published` vers
/// SwiftUI ne partent que lorsqu'au moins une vue a appelé `retainUI()` —
/// sinon chaque tick souris reconstruit des milliers de `Label`/`Image` qui
/// s'accumulent en RAM (observé : ~365k nœuds / ~670 Mo après quelques jours).
@MainActor
final class AppState: ObservableObject {
    private let store = StatsStore()
    private let achievementStore = AchievementStore()
    private let monitor = EventMonitor()
    private let metrics = DisplayMetrics()

    /// Clé du jour courant.
    @Published private(set) var currentDayKey: String = Date().dayKey

    /// Compteur de révision des stats : les vues qui lisent `today` / `history`
    /// s'abonnent via `@ObservedObject` et se rafraîchissent quand il change.
    /// Les données elles-mêmes vivent dans des storages non-`@Published` pour
    /// pouvoir les mettre à jour en silence (menu bar, arrière-plan).
    @Published private(set) var statsRevision: UInt = 0

    private var historyStorage: [DayStats] = []

    /// Stats du jour courant — toujours lues depuis le store (à jour même
    /// sans consommateur UI / sans publication SwiftUI).
    var today: DayStats { store.stats(for: currentDayKey) }
    /// Historique trié par date croissante (pour les graphiques).
    var history: [DayStats] { historyStorage }

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
    private var heavySyncWorkItem: DispatchWorkItem?
    private var isRunning = false
    private var terminateObserver: NSObjectProtocol?

    /// Nombre de fenêtres / menus qui observent l'état.
    private var uiConsumerCount = 0

    /// Intervalle minimum entre deux publications UI « légères » (`today`).
    private let uiSyncInterval: TimeInterval = 1.0
    /// Intervalle pour historique + évaluation des achievements (plus coûteux).
    private let heavySyncInterval: TimeInterval = 5.0

    /// Totaux lifetime mis à jour de façon incrémentale (évite de re-parcourir
    /// tout l'historique à chaque calcul de `playerLevel`).
    private var lifetimeKeystrokes = 0
    private var lifetimeMouseDistanceCm = 0.0
    private var lifetimeClicks = 0
    private var achievementBonusXP = 0.0

    /// Horodatage du dernier événement souris, pour calculer la vitesse.
    private var lastMouseTimestamp: TimeInterval?
    /// Au-delà de cet écart entre deux événements, on considère que le
    /// déplacement a été interrompu (pas de calcul de vitesse).
    private let maxMovementGap: TimeInterval = 0.3
    /// Plancher du pas de temps, pour éviter des pics de vitesse irréalistes.
    private let minMovementDelta: TimeInterval = 0.008

    init() {
        let key = Date().dayKey
        refreshHistoryStorage()
        rebuildLifetimeTotals()
        syncAchievementsFromStore()
        _ = achievementStore.retroactiveScan(
            history: historyStorage,
            globalKeyCounts: globalKeyCounts,
            currentDayKey: key
        )
        syncAchievementsFromStore()
        rebuildAchievementBonusXP()
        configureMonitor()
    }

    /// Indique qu'une vue SwiftUI observe cet état (dashboard, réglages, menu).
    func retainUI() {
        uiConsumerCount += 1
        if uiConsumerCount == 1 {
            syncPublishedStats(forceHeavy: true)
        }
    }

    /// Libère un consommateur UI. En arrière-plan pur, plus de publications.
    func releaseUI() {
        uiConsumerCount = max(0, uiConsumerCount - 1)
        if uiConsumerCount == 0 {
            uiSyncWorkItem?.cancel()
            uiSyncWorkItem = nil
            heavySyncWorkItem?.cancel()
            heavySyncWorkItem = nil
        }
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
        terminateObserver = NotificationCenter.default.addObserver(
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
                Task { await Leaderboard.submit(today: today, lifetimeXP: self.playerLevel.lifetimeXP) }
            }
        }
    }

    func stop() {
        monitor.stop()
        dayCheckTimer?.invalidate()
        permissionTimer?.invalidate()
        leaderboardTimer?.invalidate()
        dayCheckTimer = nil
        permissionTimer = nil
        leaderboardTimer = nil
        heavySyncWorkItem?.cancel()
        heavySyncWorkItem = nil
        uiSyncWorkItem?.cancel()
        uiSyncWorkItem = nil
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
        refreshHistoryStorage()
        store.saveNow()
        achievementStore.saveNow()
        isRunning = false
    }

    var storageURL: URL { store.storageURL }
    var allDays: [String: DayStats] { store.days }

    /// Nombre total de frappes sur toutes les journées enregistrées.
    var totalKeystrokes: Int { lifetimeKeystrokes }

    /// Niveau de progression, dérivé des stats cumulées + bonus d'achievements.
    var playerLevel: PlayerLevel {
        let base = Double(lifetimeKeystrokes) * PlayerLevel.xpPerKeystroke
            + lifetimeMouseDistanceCm * PlayerLevel.xpPerCm
            + Double(lifetimeClicks) * PlayerLevel.xpPerClick
        return PlayerLevel(lifetimeXP: base + achievementBonusXP + Double(Leaderboard.trophyXP))
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
        lifetimeMouseDistanceCm += cm
        scheduleUISync()
        store.scheduleSave()
    }

    private func recordClick(_ button: MouseButton) {
        checkDayRollover()
        store.incrementClick(button, in: currentDayKey)
        lifetimeClicks += 1
        scheduleUISync()
        store.scheduleSave()
    }

    private func recordKey(_ label: String) {
        checkDayRollover()
        store.incrementKey(label, in: currentDayKey)
        globalKeyCounts[label, default: 0] += 1
        lifetimeKeystrokes += 1
        scheduleUISync()
        store.scheduleSave()
    }

    /// Planifie une synchro UI débouncée (mouvements souris à haute fréquence).
    private func scheduleUISync() {
        guard uiConsumerCount > 0 else { return }
        guard uiSyncWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.uiSyncWorkItem = nil
            self.syncPublishedStats(forceHeavy: false)
        }
        uiSyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + uiSyncInterval, execute: work)
    }

    private func syncPublishedStats(forceHeavy: Bool) {
        // Les vues relisent `today` depuis le store après ce bump.
        bumpStatsRevision()

        if forceHeavy {
            heavySyncWorkItem?.cancel()
            heavySyncWorkItem = nil
            refreshHistoryStorage()
            bumpStatsRevision()
            evaluateAchievements()
            return
        }

        guard heavySyncWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.heavySyncWorkItem = nil
            guard self.uiConsumerCount > 0 else { return }
            self.refreshHistoryStorage()
            self.bumpStatsRevision()
            self.evaluateAchievements()
        }
        heavySyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + heavySyncInterval, execute: work)
    }

    private func bumpStatsRevision() {
        guard uiConsumerCount > 0 else { return }
        statsRevision &+= 1
    }

    private func syncAchievementsFromStore() {
        achievements = achievementStore.unlocks.sorted { $0.unlockedAt > $1.unlockedAt }
    }

    private func rebuildLifetimeTotals() {
        lifetimeKeystrokes = historyStorage.totalKeystrokes
        lifetimeMouseDistanceCm = historyStorage.totalMouseDistanceCm
        lifetimeClicks = historyStorage.totalClicks
    }

    private func rebuildAchievementBonusXP() {
        achievementBonusXP = achievements.reduce(0.0) { $0 + $1.definition.tier.xpBonus }
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
            history: historyStorage,
            globalKeyCounts: globalKeyCounts,
            alreadyUnlockedKeys: achievementStore.unlockedKeys,
            currentDayKey: currentDayKey
        )
        let added = achievementStore.add(newUnlocks, dayKey: currentDayKey)
        guard !added.isEmpty else { return }

        syncAchievementsFromStore()
        for unlock in added {
            achievementBonusXP += unlock.definition.tier.xpBonus
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
        refreshHistoryStorage()
        bumpStatsRevision()
    }

    private func refreshHistoryStorage() {
        let todayStats = store.stats(for: currentDayKey)
        if let index = historyStorage.firstIndex(where: { $0.date == currentDayKey }) {
            guard historyStorage[index] != todayStats else { return }
            historyStorage[index] = todayStats
        } else {
            historyStorage = store.days.values.sorted { $0.date < $1.date }
            globalKeyCounts = historyStorage.aggregatedKeyCounts
            rebuildLifetimeTotals()
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
        refreshHistoryStorage()
        bumpStatsRevision()
    }
}
