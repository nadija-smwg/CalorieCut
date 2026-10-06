import Foundation

extension ProfileDraft {
    init(_ profile: UserProfile) {
        name = profile.name; age = profile.age; sex = Sex(rawValue: profile.sex) ?? .male
        height = profile.height; weight = profile.currentWeight; targetWeight = profile.targetWeight
        waist = profile.initialWaist; activity = ActivityLevel(rawValue: profile.activityLevel) ?? .light
        goal = Goal(rawValue: profile.goal) ?? .lose; weeklyChange = profile.weeklyChange
        calories = profile.dailyCalorieGoal; protein = profile.proteinGoal; carbs = profile.carbGoal
        fat = profile.fatGoal; water = profile.waterGoal
    }
}
extension FoodDraft {
    init(_ entry: FoodEntry) {
        id = entry.id; name = entry.foodName; serving = entry.serving; quantity = entry.quantity
        calories = entry.calories; protein = entry.protein; carbs = entry.carbs; fat = entry.fat
        category = FoodCategory(rawValue: entry.category) ?? .other
        meal = MealType(rawValue: entry.mealType) ?? .breakfast; date = entry.date
    }
    init(_ food: FoodItem, meal: MealType, date: Date) {
        name = food.name; serving = food.defaultServing; calories = food.calories; protein = food.protein
        carbs = food.carbs; fat = food.fat; category = FoodCategory(rawValue: food.category) ?? .other
        self.meal = meal; self.date = date
    }
    init(_ food: SavedMealFood, meal: MealType, date: Date) {
        name = food.name; serving = food.serving; quantity = food.quantity; calories = food.calories
        protein = food.protein; carbs = food.carbs; fat = food.fat
        category = FoodCategory(rawValue: food.category) ?? .other; self.meal = meal; self.date = date
    }
}
extension DailyStatistics {
    static func calculate(date: Date, foods: [FoodEntry], water: [WaterEntry], calendar: Calendar = .current) -> Self {
        calculate(date: date, foods: foods.map { FoodLog($0) }, water: water.map { WaterLog($0) }, calendar: calendar)
    }

}
extension WeeklyReport {
    static func make(ending: Date, foods: [FoodEntry], water: [WaterEntry], calendar: Calendar = .current) -> Self {
        make(ending: ending, foods: foods.map { FoodLog($0) }, water: water.map { WaterLog($0) }, calendar: calendar)
    }

    static func advice(measurements: [WeightEntry], goal: Goal, loggedDays: Int, calendar: Calendar = .current) -> String {
        advice(measurements: measurements.map { WeightSample(date: $0.date, weight: $0.weight) },
               goal: goal, loggedDays: loggedDays, calendar: calendar)
    }
}

extension FoodLog {
    init(_ entry: FoodEntry) {
        date = entry.date; nutrition = entry.nutrition
        meal = MealType(rawValue: entry.mealType) ?? .snack
        category = FoodCategory(rawValue: entry.category) ?? .other
    }
}
extension WaterLog { init(_ entry: WaterEntry) { date = entry.date; amount = entry.amount } }
