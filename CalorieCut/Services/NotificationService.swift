import Foundation
import UserNotifications

@MainActor final class NotificationService {
    private let center: UNUserNotificationCenter
    init(center: UNUserNotificationCenter = .current()) { self.center = center }
    private var identifiers: [String] { ReminderPreference.defaults.map { "caloriecut.\($0.id)" } }
    static func requests(for preferences: [ReminderPreference]) throws -> [UNNotificationRequest] {
        let allowedIDs = Set(ReminderPreference.defaults.map(\.id))
        guard Set(preferences.map(\.id)).count == preferences.count,
              preferences.allSatisfy({ allowedIDs.contains($0.id) && (0...23).contains($0.hour) && (0...59).contains($0.minute) }) else {
            throw AppError.invalid("Reminder identifiers or times are invalid.")
        }
        return preferences.filter(\.enabled).map { reminder in
            let content = UNMutableNotificationContent()
            content.title = "CalorieCut · \(reminder.title)"; content.body = reminder.body; content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute), repeats: true)
            return UNNotificationRequest(identifier: "caloriecut.\(reminder.id)", content: content, trigger: trigger)
        }
    }
    func schedule(_ preferences: [ReminderPreference]) async throws {
        let requests = try Self.requests(for: preferences)
        if !requests.isEmpty {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard allowed else { throw AppError.invalid("Notifications are disabled. Allow CalorieCut notifications in iPhone Settings to use reminders.") }
        }
        let previous = await center.pendingNotificationRequests().filter { identifiers.contains($0.identifier) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        do {
            for request in requests { try await center.add(request) }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            for request in previous { try? await center.add(request) }
            throw error
        }
    }
    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
