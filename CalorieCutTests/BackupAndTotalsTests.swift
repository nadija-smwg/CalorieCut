import XCTest
@testable import CalorieCut

final class BackupAndTotalsTests: XCTestCase {
    private func backup() -> BackupEnvelope {
        var food = FoodDraft(); food.name = "Apple"; food.serving = "1 medium"
        food.calories = 95; food.carbs = 25; food.category = .fruit
        return .init(profile: .init(id: UUID(), createdAt: .now, values: ProfileDraft()), foods: [],
                     entries: [.init(id: food.id, createdAt: .now, values: food)], meals: [],
                     measurements: [.init(id: UUID(), date: .now, weight: 65, waist: 82, notes: "Starting point")],
                     water: [.init(id: UUID(), date: .now, amount: 250)],
                     notes: [.init(id: UUID(), date: Date.now.startOfDay, text: "Walked more", steps: 3000)],
                     settings: .init(weightUnit: "kg", lengthUnit: "cm", theme: .dark, reminders: ReminderPreference.defaults))
    }
    func testJSONSchemaRoundTrip() throws {
        let original = backup()
        let data = try BackupCodec.encode(original)
        let result = try BackupCodec.decode(data)
        XCTAssertEqual(result.version, 1)
        XCTAssertEqual(result.profile?.values, original.profile?.values)
        XCTAssertEqual(result.entries[0].values.name, "Apple")
        XCTAssertEqual(result.entries[0].values.calories, 95)
        XCTAssertEqual(result.entries[0].id, original.entries[0].id)
        XCTAssertEqual(result.measurements[0].waist, 82)
        XCTAssertEqual(result.water[0].amount, 250)
        XCTAssertEqual(result.notes[0].steps, 3000)
        XCTAssertEqual(result.settings.theme, .dark)
    }
    func testRejectsUnsupportedVersion() {
        var value = backup(); value.version = 2
        XCTAssertThrowsError(try BackupCodec.validate(value))
    }
    func testRejectsDuplicateIDs() {
        var value = backup(); value.entries.append(value.entries[0])
        XCTAssertThrowsError(try BackupCodec.validate(value))
    }
    func testRejectsInvalidMeasurementWaterAndSteps() {
        var value = backup(); value.measurements[0].weight = -1
        XCTAssertThrowsError(try BackupCodec.validate(value))
        value = backup(); value.water[0].amount = .infinity
        XCTAssertThrowsError(try BackupCodec.validate(value))
        value = backup(); value.notes[0].steps = -10
        XCTAssertThrowsError(try BackupCodec.validate(value))
    }
    func testRejectsInvalidFoodAndEmptyMeal() {
        var value = backup(); value.entries[0].values.quantity = -1
        XCTAssertThrowsError(try BackupCodec.validate(value))
        value = backup(); value.meals = [.init(id: UUID(), name: "Empty", createdAt: .now, foods: [])]
        XCTAssertThrowsError(try BackupCodec.validate(value))
    }
    func testRejectsMalformedJSONAndOversizedData() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("not a backup".utf8)))
        XCTAssertThrowsError(try BackupCodec.decode(Data(repeating: 0, count: 25_000_001)))
    }
    func testReminderValidationAndRoundTrip() throws {
        var value = backup(); value.settings.reminders[0].enabled = true
        value.settings.reminders[0].hour = 6; value.settings.reminders[0].minute = 45
        let result = try BackupCodec.decode(BackupCodec.encode(value))
        XCTAssertEqual(result.settings.reminders[0].hour, 6)
        XCTAssertEqual(result.settings.reminders[0].minute, 45)
        XCTAssertTrue(result.settings.reminders[0].enabled)
        value.settings.reminders[0].hour = 25
        XCTAssertThrowsError(try BackupCodec.validate(value))
    }
    func testDailyTotalsMacrosWaterCategoriesAndDayIsolation() {
        let today = Date.now.startOfDay
        let foods = [
            FoodLog(date: today.addingTimeInterval(3600), nutrition: .init(calories: 200, protein: 10, carbs: 20, fat: 5) * 2, meal: .breakfast, category: .grain),
            FoodLog(date: today.addingTimeInterval(7200), nutrition: .init(calories: 100, protein: 1, carbs: 25, fat: 0), meal: .snack, category: .fruit),
            FoodLog(date: today.dayOffset(-1), nutrition: .init(calories: 999), meal: .dinner, category: .other)
        ]
        let water = [WaterLog(date: today, amount: 250), WaterLog(date: today, amount: 500), WaterLog(date: today.dayOffset(-1), amount: 1000)]
        let stats = DailyStatistics.calculate(date: today, foods: foods, water: water)
        XCTAssertEqual(stats.nutrition, .init(calories: 500, protein: 21, carbs: 65, fat: 10))
        XCTAssertEqual(stats.entryCount, 2); XCTAssertEqual(stats.produceCount, 1)
        XCTAssertEqual(stats.mealCalories[.breakfast], 400); XCTAssertEqual(stats.mealCalories[.snack], 100)
        XCTAssertEqual(stats.water, 750)
    }
    func testWeeklyRangeIncludesSevenCalendarDays() {
        let today = Date.now.startOfDay
        let foods = (-8...0).map { FoodLog(date: today.dayOffset($0), nutrition: .init(calories: 1900, protein: 120), meal: .lunch, category: .other) }
        let report = WeeklyReport.make(ending: today, foods: foods, water: [WaterLog]())
        XCTAssertEqual(report.days.count, 7); XCTAssertEqual(report.loggedDays.count, 7)
        XCTAssertEqual(report.averageCalories, 1900); XCTAssertEqual(report.averageProtein, 120)
        XCTAssertEqual(report.calorieHits(goal: 1900), 7)
    }
    func testWeightAdviceForGradualFastAndStableTrends() {
        let today = Date.now.startOfDay
        let gradual = [WeightSample(date: today.dayOffset(-7), weight: 65), WeightSample(date: today, weight: 64.7)]
        XCTAssertTrue(WeeklyReport.advice(measurements: gradual, goal: .lose, loggedDays: 7).contains("gradual"))
        let fast = [WeightSample(date: today.dayOffset(-7), weight: 65), WeightSample(date: today, weight: 63)]
        XCTAssertTrue(WeeklyReport.advice(measurements: fast, goal: .lose, loggedDays: 7).contains("quickly"))
        let stable = [WeightSample(date: today.dayOffset(-24), weight: 65), WeightSample(date: today, weight: 65)]
        XCTAssertTrue(WeeklyReport.advice(measurements: stable, goal: .lose, loggedDays: 7).contains("stable"))
        XCTAssertTrue(WeeklyReport.advice(measurements: stable, goal: .lose, loggedDays: 1).contains("few more"))
    }
}
