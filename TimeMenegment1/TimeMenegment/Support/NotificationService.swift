// NotificationService.swift
// c11 — Local notifications for morning reminder

import Foundation
import UserNotifications

/// Manages local notifications — morning reminder for today's mission.
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private static let morningReminderId = "c11.morningReminder"

    private init() {}

    /// Request notification permission. Call when user enables reminders.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Schedule daily morning reminder at given hour:minute.
    func scheduleMorningReminder(hour: Int, minute: Int) {
        removeMorningReminder()

        let content = UNMutableNotificationContent()
        content.title = "Your day awaits"
        content.body = morningReminderBody()
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.morningReminderId, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule: \(error)")
            }
        }
    }

    /// Remove morning reminder.
    func removeMorningReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningReminderId])
    }

    private func morningReminderBody() -> String {
        guard let day = DataVault.shared.currentFieldDay(),
              let zone = DataVault.shared.zone(by: day.assignedZoneId) else {
            return "Open c11 to plan your day"
        }
        let count = day.deploymentQueue.count
        if count == 0 {
            return "\(zone.title) — add stops for today"
        }
        return "\(zone.title) — \(count) stops today"
    }
}
