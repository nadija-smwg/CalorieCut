import XCTest
import UserNotifications
@testable import CalorieCut

@MainActor final class NotificationTests: XCTestCase {
    func testDisabledRemindersProduceNoRequests() throws {
        XCTAssertTrue(try NotificationService.requests(for: ReminderPreference.defaults).isEmpty)
    }
    func testEnabledReminderHasCustomizedRepeatingTime() throws {
        var preferences = ReminderPreference.defaults
        preferences[0].enabled = true; preferences[0].hour = 9; preferences[0].minute = 35
        let requests = try NotificationService.requests(for: preferences)
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.identifier, "caloriecut.breakfast")
        XCTAssertFalse(request.content.body.isEmpty)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 35)
    }
    func testAllSixRemindersHaveUniqueRequests() throws {
        let preferences = ReminderPreference.defaults.map { var value = $0; value.enabled = true; return value }
        let requests = try NotificationService.requests(for: preferences)
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 6)
    }
    func testInvalidTimesAndDuplicateIdentifiersRejected() {
        var preferences = ReminderPreference.defaults; preferences[0].hour = 24
        XCTAssertThrowsError(try NotificationService.requests(for: preferences))
        preferences = ReminderPreference.defaults; preferences.append(preferences[0])
        XCTAssertThrowsError(try NotificationService.requests(for: preferences))
    }
}
