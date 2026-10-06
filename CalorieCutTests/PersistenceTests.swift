import XCTest
import SwiftData
@testable import CalorieCut

@MainActor final class PersistenceTests: XCTestCase {
    private var schema: Schema { Schema([UserProfile.self, FoodItem.self, FoodEntry.self, SavedMeal.self, SavedMealFood.self, WeightEntry.self, WaterEntry.self, DailyNote.self, UserSettings.self]) }
    private func makeStore() throws -> (ModelContainer, AppStore) {
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        return (container, try AppStore(context: container.mainContext))
    }
    private func sample(date: Date = .now) -> FoodDraft {
        var value = FoodDraft(meal: .lunch, date: date); value.name = "Rice"; value.serving = "1 cup"
        value.quantity = 2; value.calories = 200; value.protein = 4; value.carbs = 44; value.fat = 1
        return value
    }
    func testFirstLaunchAndProfileSaving() throws {
        let (container, store) = try makeStore()
        XCTAssertNil(store.profile)
        XCTAssertTrue(store.saveProfile(ProfileDraft()))
        let reloaded = try AppStore(context: ModelContext(container))
        XCTAssertEqual(reloaded.profile?.name, "Nadija")
        XCTAssertEqual(reloaded.foods.count, 14)
        XCTAssertEqual(reloaded.measurements.count, 1)
        var changed = reloaded.goals; changed.name = "Sam"
        XCTAssertTrue(reloaded.saveProfile(changed))
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<UserProfile>()).count, 1)
    }
    func testAddEditDeleteAndDayTotals() throws {
        let (_, store) = try makeStore()
        XCTAssertTrue(store.saveFood(sample()))
        var stats = store.stats(on: .now)
        XCTAssertEqual(stats.nutrition, .init(calories: 400, protein: 8, carbs: 88, fat: 2))
        let entry = try XCTUnwrap(store.entries.first)
        var changed = FoodDraft(entry); changed.quantity = 0.5
        XCTAssertTrue(store.saveFood(changed, editing: entry))
        stats = store.stats(on: .now)
        XCTAssertEqual(stats.nutrition.calories, 100)
        XCTAssertEqual(stats.mealCalories[.lunch], 100)
        XCTAssertTrue(store.saveFood(sample(date: Date.now.dayOffset(-1))))
        XCTAssertEqual(store.stats(on: .now).entryCount, 1)
        store.delete(entry)
        XCTAssertEqual(store.stats(on: .now).entryCount, 0)
        XCTAssertEqual(store.entries.count, 1)
    }
    func testDuplicateMoveAndCopy() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveFood(sample()))
        let entry = try XCTUnwrap(store.entries.first)
        store.duplicate(entry); XCTAssertEqual(store.entries.count, 2)
        store.move(entry, to: .dinner); XCTAssertEqual(store.foods(on: .now, meal: .dinner).count, 1)
        store.duplicate(entry, date: Date.now.dayOffset(-1), meal: .breakfast)
        XCTAssertEqual(store.foods(on: Date.now.dayOffset(-1), meal: .breakfast).count, 1)
    }
    func testReusableFoodHistorySnapshotAndFavorites() throws {
        let (_, store) = try makeStore()
        XCTAssertTrue(store.saveLibraryFood(sample()))
        let food = try XCTUnwrap(store.foods.first)
        XCTAssertTrue(store.saveFood(FoodDraft(food, meal: .breakfast, date: .now), source: food))
        var edited = sample(); edited.calories = 900
        XCTAssertTrue(store.saveLibraryFood(edited, editing: food))
        XCTAssertEqual(store.entries.first?.nutrition.calories, 200)
        store.favorite(food); XCTAssertTrue(food.isFavorite)
        XCTAssertNotNil(food.lastUsedAt)
    }
    func testSavedMealLoggingAndCascadeDeletion() throws {
        let (_, store) = try makeStore()
        XCTAssertTrue(store.saveMeal(name: "Breakfast", foods: [sample(), sample()]))
        let meal = try XCTUnwrap(store.meals.first)
        XCTAssertEqual(meal.nutrition.calories, 800)
        XCTAssertTrue(store.addMeal(meal, to: .breakfast, date: .now))
        XCTAssertEqual(store.stats(on: .now).nutrition.calories, 800)
        store.delete(meal)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<SavedMealFood>()).count, 0)
        XCTAssertEqual(store.entries.count, 2)
    }
    func testWaterNotesWeightAndWaist() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveProfile(ProfileDraft()))
        XCTAssertTrue(store.addWater(amount: 250, date: .now))
        XCTAssertTrue(store.addWater(amount: 500, date: .now))
        XCTAssertEqual(store.stats(on: .now).water, 750)
        XCTAssertTrue(store.saveNote(date: .now, text: "Walked more", steps: 3000))
        XCTAssertTrue(store.saveNote(date: .now, text: "Updated", steps: 3500))
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.note(on: .now)?.steps, 3500)
        XCTAssertTrue(store.saveMeasurement(date: .now, weight: 64.7, waist: 81.5, notes: "Morning"))
        XCTAssertEqual(store.profile?.currentWeight, 64.7)
        XCTAssertEqual(store.measurements.last?.waist, 81.5)
        XCTAssertTrue(store.saveMeasurement(date: Date.now.dayOffset(-2), weight: 66, waist: nil, notes: "Earlier"))
        XCTAssertEqual(store.profile?.currentWeight, 64.7)
    }
    func testJSONRoundTripReplacesInsteadOfDuplicating() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveProfile(ProfileDraft()))
        XCTAssertTrue(store.saveFood(sample(), reusable: true))
        XCTAssertTrue(store.saveMeal(name: "My meal", foods: [sample()]))
        XCTAssertTrue(store.addWater(amount: 500, date: .now))
        XCTAssertTrue(store.saveNote(date: .now, text: "Backup test", steps: 2000))
        let backup = try BackupService.decode(BackupService.export(store: store))
        XCTAssertTrue(store.saveFood(sample()))
        XCTAssertTrue(BackupService.restore(backup, store: store))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.foods.count, 15)
        XCTAssertEqual(store.meals.count, 1)
        XCTAssertEqual(store.stats(on: .now).nutrition.calories, 400)
        XCTAssertEqual(store.stats(on: .now).water, 500)
        XCTAssertEqual(store.note(on: .now)?.text, "Backup test")
        XCTAssertTrue(BackupService.restore(backup, store: store))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<SavedMealFood>()).count, 1)
    }
    func testInvalidBackupCannotEraseExistingData() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveFood(sample()))
        var backup = BackupService.envelope(store: store); backup.version = 999
        XCTAssertFalse(BackupService.restore(backup, store: store))
        XCTAssertEqual(store.entries.count, 1)
        backup.version = 1; backup.entries[0].values.quantity = -5
        XCTAssertThrowsError(try BackupService.validate(backup))
        XCTAssertEqual(store.entries.count, 1)
    }
    func testDuplicateBackupIDsRejected() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveFood(sample()))
        var backup = BackupService.envelope(store: store); backup.entries.append(backup.entries[0])
        XCTAssertThrowsError(try BackupService.validate(backup))
    }
    func testPersistenceAfterStoreReopenOnDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        func write() throws {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let store = try AppStore(context: container.mainContext)
            XCTAssertTrue(store.saveProfile(ProfileDraft()))
            XCTAssertTrue(store.saveFood(sample()))
            XCTAssertTrue(store.addWater(amount: 250, date: .now))
        }
        try write()
        let reopened = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        let store = try AppStore(context: reopened.mainContext)
        XCTAssertEqual(store.profile?.name, "Nadija")
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.stats(on: .now).nutrition.calories, 400)
        XCTAssertEqual(store.stats(on: .now).water, 250)
    }
    func testWeeklyAdviceNeedsEnoughMeasurements() throws {
        let readings = [WeightEntry(date: .now.dayOffset(-7), weight: 65, waist: 82), WeightEntry(date: .now, weight: 64.7, waist: 81.5)]
        XCTAssertTrue(WeeklyReport.advice(measurements: readings, goal: .lose, loggedDays: 7).contains("gradual"))
        let fast = [WeightEntry(date: .now.dayOffset(-7), weight: 65, waist: nil), WeightEntry(date: .now, weight: 63, waist: nil)]
        XCTAssertTrue(WeeklyReport.advice(measurements: fast, goal: .lose, loggedDays: 7).contains("quickly"))
        let stable = [WeightEntry(date: .now.dayOffset(-24), weight: 65, waist: nil), WeightEntry(date: .now, weight: 65, waist: nil)]
        XCTAssertTrue(WeeklyReport.advice(measurements: stable, goal: .lose, loggedDays: 7).contains("stable"))
    }
    func testDeleteEverythingAndRestartOnboarding() throws {
        let (_, store) = try makeStore(); XCTAssertTrue(store.saveProfile(ProfileDraft()))
        XCTAssertTrue(store.saveFood(sample()))
        XCTAssertTrue(store.deleteAll())
        XCTAssertNil(store.profile); XCTAssertTrue(store.entries.isEmpty); XCTAssertTrue(store.foods.isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<UserSettings>()).count, 1)
    }
}
