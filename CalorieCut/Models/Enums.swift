import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male = "Male", female = "Female"
    var id: String { rawValue }
}
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "Sedentary", light = "Lightly active", moderate = "Moderately active", very = "Very active"
    var id: String { rawValue }
    var multiplier: Double {
        switch self { case .sedentary: 1.2; case .light: 1.375; case .moderate: 1.55; case .very: 1.725 }
    }
}
enum Goal: String, Codable, CaseIterable, Identifiable {
    case lose = "Lose fat", maintain = "Maintain weight", gain = "Gain weight"
    var id: String { rawValue }
}
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast", lunch = "Lunch", dinner = "Dinner", snack = "Snacks"
    var id: String { rawValue }
    var icon: String {
        switch self { case .breakfast: "sunrise.fill"; case .lunch: "sun.max.fill"; case .dinner: "moon.fill"; case .snack: "carrot.fill" }
    }
}
enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case other = "Other", fruit = "Fruit", vegetable = "Vegetable", protein = "Protein", grain = "Grain", dairy = "Dairy", drink = "Drink"
    var id: String { rawValue }
}
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
}

