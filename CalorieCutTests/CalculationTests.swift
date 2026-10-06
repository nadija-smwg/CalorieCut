import XCTest
@testable import CalorieCut

final class CalculationTests: XCTestCase {
    func testMaleBMR() {
        XCTAssertEqual(CalorieCalculator.bmr(weight: 65, height: 175, age: 22, sex: .male), 1638.75, accuracy: 0.01)
    }
    func testFemaleBMR() {
        XCTAssertEqual(CalorieCalculator.bmr(weight: 65, height: 175, age: 22, sex: .female), 1472.75, accuracy: 0.01)
    }
    func testActivityMultipliersAndMaintenance() {
        var draft = ProfileDraft(); draft.goal = .maintain
        for activity in ActivityLevel.allCases {
            draft.activity = activity
            let result = CalorieCalculator.suggestion(draft)
            XCTAssertEqual(result.tdee, result.bmr * activity.multiplier, accuracy: 0.01)
            XCTAssertEqual(result.target, (result.tdee / 10).rounded() * 10, accuracy: 0.01)
        }
    }
    func testDefaultModerateDeficit() {
        let result = CalorieCalculator.suggestion(ProfileDraft())
        XCTAssertEqual(result.tdee, 2253.28125, accuracy: 0.01)
        XCTAssertEqual(result.target, 1980, accuracy: 0.01)
    }
    func testDeficitIsCapped() {
        var draft = ProfileDraft(); draft.weeklyChange = 1
        let result = CalorieCalculator.suggestion(draft)
        XCTAssertTrue(result.adjustedForSafety)
        XCTAssertLessThanOrEqual(result.tdee - result.target, min(result.tdee * 0.2, 500) + 5)
    }
    func testMinimumIntake() {
        var draft = ProfileDraft(); draft.sex = .female; draft.weight = 40; draft.height = 145
        draft.age = 80; draft.activity = .sedentary; draft.weeklyChange = 1
        let result = CalorieCalculator.suggestion(draft)
        XCTAssertEqual(result.target, 1200)
        XCTAssertTrue(result.adjustedForSafety)
        draft.calories = 900
        XCTAssertNotNil(draft.validation)
    }
    func testGainSurplusCapped() {
        var draft = ProfileDraft(); draft.goal = .gain; draft.weeklyChange = 1
        let result = CalorieCalculator.suggestion(draft)
        XCTAssertEqual(result.target, ((result.tdee + 350) / 10).rounded() * 10)
    }
    func testNutritionArithmetic() {
        let a = Nutrition(calories: 100, protein: 10, carbs: 20, fat: 2)
        let b = Nutrition(calories: 50, protein: 5, carbs: 3, fat: 1)
        XCTAssertEqual(a * 2 + b, Nutrition(calories: 250, protein: 25, carbs: 43, fat: 5))
    }
    func testIdealReviewScore() {
        let goals = ProfileDraft()
        let stats = DailyStatistics(date: .now, nutrition: .init(calories: 1900, protein: 120), water: 2500,
                                    entryCount: 6, produceCount: 3, mealCalories: [.breakfast: 500, .lunch: 700, .dinner: 700])
        let review = ReviewEngine.daily(stats, goals: goals, complete: true)
        XCTAssertEqual(review.score, 10)
        XCTAssertEqual(review.rating, "Excellent")
    }
    func testEmptyReviewHasNoScore() {
        let stats = DailyStatistics(date: .now, nutrition: .zero, water: 0, entryCount: 0, produceCount: 0, mealCalories: [:])
        XCTAssertNil(ReviewEngine.daily(stats, goals: ProfileDraft(), complete: true).score)
    }
    func testLowCaloriesDoNotEarnPerfectScore() {
        let stats = DailyStatistics(date: .now, nutrition: .init(calories: 400, protein: 120), water: 2500,
                                    entryCount: 6, produceCount: 3, mealCalories: [.breakfast: 100, .lunch: 100, .dinner: 200])
        let result = ReviewEngine.daily(stats, goals: ProfileDraft(), complete: true)
        XCTAssertLessThan(result.score ?? 10, 8)
        XCTAssertTrue(result.messages.contains(where: { $0.contains("well below") }))
    }
    func testOverTargetScoreIsBounded() {
        let stats = DailyStatistics(date: .now, nutrition: .init(calories: 10000, protein: 1000), water: 10000,
                                    entryCount: 6, produceCount: 10, mealCalories: [.dinner: 10000])
        let score = ReviewEngine.daily(stats, goals: ProfileDraft(), complete: true).score ?? -1
        XCTAssertGreaterThanOrEqual(score, 0); XCTAssertLessThanOrEqual(score, 10)
    }
    func testWeeklyAveragesExcludeMissingDays() {
        let days = [
            DailyStatistics(date: .now, nutrition: .init(calories: 1800, protein: 100), water: 0, entryCount: 1, produceCount: 0, mealCalories: [:]),
            DailyStatistics(date: .now, nutrition: .init(calories: 2000, protein: 120), water: 0, entryCount: 1, produceCount: 0, mealCalories: [:]),
            DailyStatistics(date: .now, nutrition: .zero, water: 0, entryCount: 0, produceCount: 0, mealCalories: [:])
        ]
        let report = WeeklyReport(days: days)
        XCTAssertEqual(report.averageCalories, 1900); XCTAssertEqual(report.averageProtein, 110)
        XCTAssertEqual(report.calorieHits(goal: 1900), 2); XCTAssertEqual(report.proteinHits(goal: 120), 1)
    }
    func testStreakCountsLoggingAndToleratesNotYetLoggedToday() {
        let today = Date.now.startOfDay
        XCTAssertEqual(ReviewEngine.streak(dates: [today, today, today.dayOffset(-1), today.dayOffset(-2)], today: today), 3)
        XCTAssertEqual(ReviewEngine.streak(dates: [today.dayOffset(-1), today.dayOffset(-2)], today: today), 2)
        XCTAssertEqual(ReviewEngine.streak(dates: [today.dayOffset(-2)], today: today), 0)
    }
    func testStreakUsesCalendarDaysAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let today = try XCTUnwrap(formatter.date(from: "2026-03-09T16:00:00Z"))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let earlier = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))
        XCTAssertEqual(ReviewEngine.streak(dates: [today, yesterday, earlier], today: today, calendar: calendar), 3)
    }
    func testUnitRoundTrips() {
        XCTAssertEqual(Units.kilograms(Units.weight(65, unit: "lb"), unit: "lb"), 65, accuracy: 0.0001)
        XCTAssertEqual(Units.centimeters(Units.length(82, unit: "in"), unit: "in"), 82, accuracy: 0.0001)
    }
    func testFoodValidationRejectsInvalidNumbers() {
        var draft = FoodDraft(); draft.name = "Test"; draft.quantity = 0
        XCTAssertNotNil(draft.validation)
        draft.quantity = 1; draft.calories = .infinity
        XCTAssertNotNil(draft.validation)
        draft.calories = 10; draft.protein = -1
        XCTAssertNotNil(draft.validation)
    }
}
