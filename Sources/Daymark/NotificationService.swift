import AppKit
import UserNotifications

enum NotificationService {
    private static let focusIdentifier = "daymark-focus-timer"

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func scheduleTaskReminder(for task: FocusTask) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let identifier = taskIdentifier(task.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let date = task.reminderAt, date > .now else { return true }
        guard await requestPermission() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Task reminder"
        content.body = task.title
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    static func cancelTaskReminder(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [taskIdentifier(id)])
    }

    static func scheduleTimerTransition(at date: Date, title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: focusIdentifier, content: content, trigger: trigger))
    }

    static func cancelTimerTransition() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
    }

    static func cancelAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    @MainActor
    static func playChime(isBreak: Bool = false) {
        let name = NSSound.Name(isBreak ? "Blow" : "Glass")
        NSSound(named: name)?.play()
    }

    private static func taskIdentifier(_ id: UUID) -> String {
        "daymark-task-\(id.uuidString)"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier == "daymark-focus-timer" ? [.banner] : [.banner, .sound]
    }
}
