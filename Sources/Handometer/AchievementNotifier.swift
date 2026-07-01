import UserNotifications

/// Gère les notifications système pour les achievements débloqués.
///
/// Un délégué est nécessaire pour que macOS affiche la bannière même quand
/// l'app est active : sans `willPresent` renvoyant `.banner`, la notification
/// n'apparaît que dans le centre de notifications (pas d'alerte).
final class AchievementNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AchievementNotifier()

    private var didRequestPermission = false

    /// À appeler au lancement pour brancher le délégué avant toute notification.
    static func configure() {
        UNUserNotificationCenter.current().delegate = shared
        shared.requestPermissionIfNeeded()
    }

    func requestPermissionIfNeeded() {
        guard !didRequestPermission else { return }
        didRequestPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(unlock: UnlockedAchievement) {
        shared.requestPermissionIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked!"
        content.body = "\(unlock.definition.title) — \(unlock.contextLabel())"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: unlock.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
