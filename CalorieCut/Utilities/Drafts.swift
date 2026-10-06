import Foundation

struct ProfileDraft: Codable, Equatable {
    var name = "Nadija"
    var age = 22
    var sex: Sex = .male
    var height = 175.0
    var weight = 65.0
    var targetWeight = 62.0
    var waist = 82.0
    var activity: ActivityLevel = .light
    var goal: Goal = .lose
    var weeklyChange = 0.25
    var calories = 1900.0
    var protein = 120.0
    var carbs = 220.0
    var fat = 65.0
    var water = 2500.0
    init() {}

    var validation: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Please enter your name." }
        if !(18...100).contains(age) { return "CalorieCut's calorie guidance is for adults aged 18–100." }
        if !height.isFinite || !(100...250).contains(height) { return "Enter a height between 100 and 250 cm." }
        if !weight.isFinite || !(30...350).contains(weight) || !targetWeight.isFinite || !(30...350).contains(targetWeight) { return "Enter weights between 30 and 350 kg." }
        if !waist.isFinite || !(30...250).contains(waist) { return "Enter a waist measurement between 30 and 250 cm." }
        if !weeklyChange.isFinite || !(0...1).contains(weeklyChange) { return "Choose a weekly change between 0 and 1 kg." }
        if !calories.isFinite || !(CalorieCalculator.minimum(sex: sex)...6000).contains(calories) { return "Choose at least \(Int(CalorieCalculator.minimum(sex: sex))) kcal, up to 6,000 kcal. Seek professional guidance for lower targets." }
        if !protein.isFinite || !(1...500).contains(protein) || !carbs.isFinite || !(1...1000).contains(carbs) || !fat.isFinite || !(1...300).contains(fat) { return "Enter positive macro goals within the displayed ranges." }
        if !water.isFinite || !(500...6000).contains(water) { return "Choose a water target between 500 and 6,000 ml." }
        return nil
    }
}
struct FoodDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var serving = "1 serving"
    var quantity = 1.0
    var calories = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
    var category: FoodCategory = .other
    var meal: MealType = .breakfast
    var date = Date.now
    init(meal: MealType = .breakfast, date: Date = .now) { self.meal = meal; self.date = date }



    var validation: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "A food name is required." }
        if serving.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Describe one serving." }
        if !quantity.isFinite || !(0.01...100).contains(quantity) { return "Quantity must be between 0.01 and 100 servings." }
        if ![calories, protein, carbs, fat].allSatisfy({ $0.isFinite && $0 >= 0 }) || calories > 10000 || protein > 1000 || carbs > 2000 || fat > 1000 { return "Enter valid, nonnegative nutrition amounts." }
        if date > Date.now.addingTimeInterval(60) { return "Food can only be logged for today or earlier." }
        return nil
    }
    var nutrition: Nutrition { Nutrition(calories: calories, protein: protein, carbs: carbs, fat: fat) * quantity }
}
struct ReminderPreference: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
    var enabled: Bool = false
    var hour: Int
    var minute: Int = 0
    static var defaults: [Self] { [
        .init(id: "breakfast", title: "Breakfast", body: "Take a moment to log your breakfast.", hour: 8),
        .init(id: "lunch", title: "Lunch", body: "Ready to log lunch?", hour: 13),
        .init(id: "dinner", title: "Dinner", body: "Log dinner when you're ready.", hour: 19),
        .init(id: "water", title: "Water", body: "Check in with your hydration today.", hour: 15),
        .init(id: "weight", title: "Weight", body: "An optional measurement can help you see your trend.", hour: 7),
        .init(id: "review", title: "Daily review", body: "Your daily reflection is ready in CalorieCut.", hour: 21)
    ] }
}
