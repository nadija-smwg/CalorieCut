import Foundation
import SwiftData

@Model final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var age: Int
    var sex: String
    var height: Double
    var currentWeight: Double
    var targetWeight: Double
    var initialWaist: Double
    var activityLevel: String
    var goal: String
    var weeklyChange: Double
    var dailyCalorieGoal: Double
    var proteinGoal: Double
    var carbGoal: Double
    var fatGoal: Double
    var waterGoal: Double
    var createdAt: Date
    init(draft: ProfileDraft, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id; self.createdAt = createdAt
        name = draft.name; age = draft.age; sex = draft.sex.rawValue; height = draft.height
        currentWeight = draft.weight; targetWeight = draft.targetWeight; initialWaist = draft.waist
        activityLevel = draft.activity.rawValue; goal = draft.goal.rawValue; weeklyChange = draft.weeklyChange
        dailyCalorieGoal = draft.calories; proteinGoal = draft.protein; carbGoal = draft.carbs
        fatGoal = draft.fat; waterGoal = draft.water
    }
    func apply(_ draft: ProfileDraft) {
        name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines); age = draft.age
        sex = draft.sex.rawValue; height = draft.height; currentWeight = draft.weight
        targetWeight = draft.targetWeight; initialWaist = draft.waist; activityLevel = draft.activity.rawValue
        goal = draft.goal.rawValue; weeklyChange = draft.weeklyChange; dailyCalorieGoal = draft.calories
        proteinGoal = draft.protein; carbGoal = draft.carbs; fatGoal = draft.fat; waterGoal = draft.water
    }
}

@Model final class FoodItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var defaultServing: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var category: String
    var isFavorite: Bool
    var isSample: Bool
    var createdAt: Date
    var lastUsedAt: Date?
    init(name: String, serving: String, calories: Double, protein: Double, carbs: Double, fat: Double,
         category: FoodCategory = .other, isSample: Bool = false) {
        id = UUID(); self.name = name; defaultServing = serving; self.calories = calories
        self.protein = protein; self.carbs = carbs; self.fat = fat; self.category = category.rawValue
        isFavorite = false; self.isSample = isSample; createdAt = .now; lastUsedAt = nil
    }
}

// Nutrition is a per-serving snapshot. Totals multiply by quantity; library edits never change history.
@Model final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var foodName: String
    var serving: String
    var quantity: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var category: String
    var mealType: String
    var date: Date
    var createdAt: Date
    init(draft: FoodDraft) {
        id = UUID(); foodName = draft.name; serving = draft.serving; quantity = draft.quantity
        calories = draft.calories; protein = draft.protein; carbs = draft.carbs; fat = draft.fat
        category = draft.category.rawValue; mealType = draft.meal.rawValue; date = draft.date; createdAt = .now
    }
    func apply(_ draft: FoodDraft) {
        foodName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines); serving = draft.serving
        quantity = draft.quantity; calories = draft.calories; protein = draft.protein
        carbs = draft.carbs; fat = draft.fat; category = draft.category.rawValue
        mealType = draft.meal.rawValue; date = draft.date
    }
    var nutrition: Nutrition { Nutrition(calories: calories, protein: protein, carbs: carbs, fat: fat) * quantity }
}

@Model final class SavedMeal {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \SavedMealFood.meal) var foods: [SavedMealFood]
    init(name: String, foods: [SavedMealFood]) { id = UUID(); self.name = name; self.foods = foods; createdAt = .now }
    var nutrition: Nutrition { foods.reduce(.zero) { $0 + $1.nutrition } }
}
@Model final class SavedMealFood {
    @Attribute(.unique) var id: UUID
    var name: String
    var serving: String
    var quantity: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var category: String
    var meal: SavedMeal?
    init(draft: FoodDraft) {
        id = UUID(); name = draft.name; serving = draft.serving; quantity = draft.quantity
        calories = draft.calories; protein = draft.protein; carbs = draft.carbs; fat = draft.fat
        category = draft.category.rawValue
    }
    var nutrition: Nutrition { Nutrition(calories: calories, protein: protein, carbs: carbs, fat: fat) * quantity }
}
@Model final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Double?
    var waist: Double?
    var notes: String
    init(date: Date, weight: Double?, waist: Double?, notes: String = "") {
        id = UUID(); self.date = date; self.weight = weight; self.waist = waist; self.notes = notes
    }
}
@Model final class WaterEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double // milliliters
    init(date: Date, amount: Double) { id = UUID(); self.date = date; self.amount = amount }
}
@Model final class DailyNote {
    @Attribute(.unique) var id: UUID
    var date: Date
    var text: String
    var steps: Int
    init(date: Date, text: String = "", steps: Int = 0) { id = UUID(); self.date = date; self.text = text; self.steps = steps }
}
@Model final class UserSettings {
    @Attribute(.unique) var id: UUID
    var weightUnit: String
    var lengthUnit: String
    var theme: String
    var remindersData: Data
    init() {
        id = UUID(); weightUnit = "kg"; lengthUnit = "cm"; theme = AppTheme.system.rawValue
        remindersData = Data()
    }
    var reminders: [ReminderPreference] {
        get { (try? JSONDecoder().decode([ReminderPreference].self, from: remindersData)) ?? ReminderPreference.defaults }
        set { if let data = try? JSONEncoder().encode(newValue) { remindersData = data } }
    }
}
