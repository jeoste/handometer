import UserNotifications

enum AchievementNotifier {
    private static var didRequestPermission = false

    static func requestPermissionIfNeeded() {
        guard !didRequestPermission else { return }
        didRequestPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(unlock: UnlockedAchievement) {
        requestPermissionIfNeeded()

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
}
