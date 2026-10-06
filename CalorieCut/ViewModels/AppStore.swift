import Foundation
import SwiftData
import Observation

@MainActor @Observable final class AppStore {
    let context: ModelContext
    var profile: UserProfile?
    var settings: UserSettings
    var foods: [FoodItem] = []
    var entries: [FoodEntry] = []
    var meals: [SavedMeal] = []
    var measurements: [WeightEntry] = []
    var water: [WaterEntry] = []
    var notes: [DailyNote] = []
    var errorMessage: String?
    var notice: String?
    let notifications = NotificationService()

    init(context: ModelContext) throws {
        self.context = context
        context.autosaveEnabled = false
        if let existing = try context.fetch(FetchDescriptor<UserSettings>()).first { settings = existing }
        else { let value = UserSettings(); context.insert(value); settings = value; try context.save() }
        try refresh()
    }
    func refresh() throws {
        profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        foods = try context.fetch(FetchDescriptor<FoodItem>()).sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        entries = try context.fetch(FetchDescriptor<FoodEntry>()).sorted { $0.date < $1.date }
        meals = try context.fetch(FetchDescriptor<SavedMeal>()).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        measurements = try context.fetch(FetchDescriptor<WeightEntry>()).sorted { $0.date < $1.date }
        water = try context.fetch(FetchDescriptor<WaterEntry>()).sorted { $0.date < $1.date }
        notes = try context.fetch(FetchDescriptor<DailyNote>())
        if let value = try context.fetch(FetchDescriptor<UserSettings>()).first { settings = value }
    }
    @discardableResult func perform(_ action: () throws -> Void) -> Bool {
        do { try action(); try context.save(); try refresh(); errorMessage = nil; return true }
        catch { context.rollback(); try? refresh(); errorMessage = error.localizedDescription; return false }
    }
    var goals: ProfileDraft { profile.map(ProfileDraft.init) ?? ProfileDraft() }
    func stats(on date: Date) -> DailyStatistics { .calculate(date: date, foods: entries, water: water) }
    func foods(on date: Date, meal: MealType? = nil) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && (meal == nil || $0.mealType == meal?.rawValue) }
    }
    func note(on date: Date) -> DailyNote? { notes.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    var streak: Int { ReviewEngine.streak(dates: entries.map(\.date)) }
    func saveProfile(_ draft: ProfileDraft) -> Bool {
        perform {
            if let message = draft.validation { throw AppError.invalid(message) }
            if let profile { profile.apply(draft) }
            else {
                context.insert(UserProfile(draft: draft))
                context.insert(WeightEntry(date: .now, weight: draft.weight, waist: draft.waist, notes: "Starting measurements"))
                for food in SampleFoods.make() { context.insert(food) }
            }
        }
    }
    func saveFood(_ draft: FoodDraft, editing: FoodEntry? = nil, reusable: Bool = false, source: FoodItem? = nil) -> Bool {
        perform {
            if let message = draft.validation { throw AppError.invalid(message) }
            if let editing { editing.apply(draft) } else { context.insert(FoodEntry(draft: draft)) }
            source?.lastUsedAt = .now
            if reusable {
                let food = FoodItem(name: draft.name, serving: draft.serving, calories: draft.calories,
                                    protein: draft.protein, carbs: draft.carbs, fat: draft.fat, category: draft.category)
                food.lastUsedAt = .now; context.insert(food)
            }
        }
    }
    func saveLibraryFood(_ draft: FoodDraft, editing: FoodItem? = nil) -> Bool {
        perform {
            if let message = draft.validation { throw AppError.invalid(message) }
            if let food = editing {
                food.name = draft.name; food.defaultServing = draft.serving; food.calories = draft.calories
                food.protein = draft.protein; food.carbs = draft.carbs; food.fat = draft.fat
                food.category = draft.category.rawValue; food.isSample = false
            } else { context.insert(FoodItem(name: draft.name, serving: draft.serving, calories: draft.calories, protein: draft.protein, carbs: draft.carbs, fat: draft.fat, category: draft.category)) }
        }
    }
    func duplicate(_ entry: FoodEntry, date: Date? = nil, meal: MealType? = nil) {
        var draft = FoodDraft(entry); draft.id = UUID()
        if let date { draft.date = date }
        if let meal { draft.meal = meal }
        _ = saveFood(draft)
    }
    func move(_ entry: FoodEntry, to meal: MealType) { perform { entry.mealType = meal.rawValue } }
    func delete<T: PersistentModel>(_ object: T) {
        perform {
            if let measurement = object as? WeightEntry,
               let latest = measurements.last(where: { $0.id != measurement.id && $0.weight != nil })?.weight {
                profile?.currentWeight = latest
            }
            context.delete(object)
        }
    }
    func favorite(_ food: FoodItem) { perform { food.isFavorite.toggle() } }
    func saveMeal(name: String, foods: [FoodDraft], editing: SavedMeal? = nil) -> Bool {
        perform {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !foods.isEmpty else { throw AppError.invalid("Give your meal a name and add at least one food.") }
            for food in foods { if let message = food.validation { throw AppError.invalid(message) } }
            if let editing {
                for part in editing.foods { context.delete(part) }
                editing.name = name; editing.foods = foods.map { SavedMealFood(draft: $0) }
            } else { context.insert(SavedMeal(name: name, foods: foods.map { SavedMealFood(draft: $0) })) }
        }
    }
    func addMeal(_ saved: SavedMeal, to meal: MealType, date: Date) -> Bool {
        perform {
            guard !saved.foods.isEmpty else { throw AppError.invalid("This meal has no foods.") }
            for part in saved.foods {
                let draft = FoodDraft(part, meal: meal, date: date)
                if let message = draft.validation { throw AppError.invalid(message) }
                context.insert(FoodEntry(draft: draft))
            }
        }
    }
    func addWater(amount: Double, date: Date) -> Bool {
        perform {
            guard amount.isFinite, (1...3000).contains(amount), date <= .now else { throw AppError.invalid("Enter 1–3,000 ml for today or an earlier date.") }
            context.insert(WaterEntry(date: date, amount: amount))
        }
    }
    func saveMeasurement(date: Date, weight: Double?, waist: Double?, notes: String, editing: WeightEntry? = nil) -> Bool {
        perform {
            guard date <= .now, weight != nil || waist != nil else { throw AppError.invalid("Enter a weight or waist measurement for today or earlier.") }
            if let weight, !weight.isFinite || !(30...350).contains(weight) { throw AppError.invalid("Weight must be between 30 and 350 kg.") }
            if let waist, !waist.isFinite || !(30...250).contains(waist) { throw AppError.invalid("Waist must be between 30 and 250 cm.") }
            if let editing { editing.date = date; editing.weight = weight; editing.waist = waist; editing.notes = notes }
            else { context.insert(WeightEntry(date: date, weight: weight, waist: waist, notes: notes)) }
            // Only the latest recorded weight updates the profile's current weight.
            let all = try context.fetch(FetchDescriptor<WeightEntry>()).filter { $0.weight != nil }.sorted { $0.date < $1.date }
            if let latest = all.last?.weight { profile?.currentWeight = latest }
        }
    }
    func saveNote(date: Date, text: String, steps: Int) -> Bool {
        perform {
            guard date <= .now, (0...100000).contains(steps) else { throw AppError.invalid("Steps must be between 0 and 100,000.") }
            if let existing = note(on: date) { existing.text = text; existing.steps = steps }
            else { context.insert(DailyNote(date: date.startOfDay, text: text, steps: steps)) }
        }
    }
    func savePreferences(weight: String, length: String, theme: AppTheme) {
        perform { settings.weightUnit = weight; settings.lengthUnit = length; settings.theme = theme.rawValue }
    }
    func setReminders(_ values: [ReminderPreference]) async -> Bool {
        do {
            try await notifications.schedule(values)
            let saved = perform { settings.reminders = values }
            if !saved { try? await notifications.schedule(settings.reminders) }
            return saved
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func deleteAll() -> Bool {
        let result = perform {
            for value in entries { context.delete(value) }; for value in foods { context.delete(value) }
            for value in meals { context.delete(value) }; for value in measurements { context.delete(value) }
            for value in water { context.delete(value) }; for value in notes { context.delete(value) }
            if let profile { context.delete(profile) }
            context.delete(settings); context.insert(UserSettings())
        }
        if result { notifications.cancelAll() }
        return result
    }
}
