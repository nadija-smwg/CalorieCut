import XCTest

final class CalorieCutUITests: XCTestCase {
    private func onboard(_ app: XCUIApplication) {
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["getStarted"].waitForExistence(timeout: 10))
        app.buttons["getStarted"].tap()
        let next = app.buttons["continueOnboarding"]
        for _ in 0..<8 where !next.isHittable { app.swipeUp() }
        XCTAssertTrue(next.isHittable); next.tap()
        let finish = app.buttons["finishOnboarding"]
        for _ in 0..<8 where !finish.isHittable { app.swipeUp() }
        XCTAssertTrue(finish.isHittable); finish.tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
    }
    func testOnboardingAndAllTabs() {
        let app = XCUIApplication(); onboard(app)
        for tab in ["Diary", "Progress", "Review", "Settings", "Home"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }
    func testManualFoodEntryAppearsInDiary() {
        let app = XCUIApplication(); onboard(app)
        app.tabBars.buttons["Diary"].tap()
        app.buttons["Add food"].firstMatch.tap()
        app.buttons["Add food manually"].tap()
        let name = app.textFields["foodName"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("Test Breakfast")
        let calories = app.textFields["Calories"]
        calories.tap()
        if let current = calories.value as? String {
            calories.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        calories.typeText("400")
        app.buttons["saveFood"].tap()
        XCTAssertTrue(app.staticTexts["Test Breakfast"].waitForExistence(timeout: 5))
    }
    func testCalendarAndReviewNavigation() {
        let app = XCUIApplication(); onboard(app)
        app.tabBars.buttons["Diary"].tap()
        app.buttons["Open calendar"].tap()
        XCTAssertTrue(app.navigationBars["Your calendar"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.tabBars.buttons["Review"].tap()
        app.buttons["Weekly"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 3))
    }
}
