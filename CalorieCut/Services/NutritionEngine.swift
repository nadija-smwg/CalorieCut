import Foundation

struct Nutrition: Codable, Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    static let zero = Nutrition()
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
              carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }
    static func * (lhs: Self, rhs: Double) -> Self {
        .init(calories: lhs.calories * rhs, protein: lhs.protein * rhs, carbs: lhs.carbs * rhs, fat: lhs.fat * rhs)
    }
}
struct CalorieSuggestion {
    let bmr: Double
    let tdee: Double
    let target: Double
    let adjustedForSafety: Bool
}
enum CalorieCalculator {
    static func bmr(weight: Double, height: Double, age: Int, sex: Sex) -> Double {
        10 * weight + 6.25 * height - 5 * Double(age) + (sex == .male ? 5 : -161)
    }
    static func minimum(sex: Sex) -> Double { sex == .male ? 1500 : 1200 }
    static func suggestion(_ draft: ProfileDraft) -> CalorieSuggestion {
        let basal = bmr(weight: draft.weight, height: draft.height, age: draft.age, sex: draft.sex)
        let maintenance = basal * draft.activity.multiplier
        let requested = max(0, draft.weeklyChange) * 7700 / 7
        // Limit a deficit to 20% of maintenance and 500 kcal/day; a surplus to 350.
        let adjustment = draft.goal == .lose ? -min(requested, maintenance * 0.2, 500) :
            draft.goal == .gain ? min(requested, 350) : 0
        let raw = maintenance + adjustment
        let target = max(minimum(sex: draft.sex), (raw / 10).rounded() * 10)
        return .init(bmr: basal, tdee: maintenance, target: target,
                     adjustedForSafety: raw < minimum(sex: draft.sex) || (draft.goal == .lose && requested > min(maintenance * 0.2, 500)))
    }
}
struct DailyStatistics {
    let date: Date
    let nutrition: Nutrition
    let water: Double
    let entryCount: Int
    let produceCount: Int
    let mealCalories: [MealType: Double]
    var mealsLogged: Int { mealCalories.values.filter { $0 > 0 }.count }
    static func calculate(date: Date, foods: [FoodLog], water: [WaterLog], calendar: Calendar = .current) -> Self {
        let entries = foods.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let drinks = water.filter { calendar.isDate($0.date, inSameDayAs: date) }
        var meals: [MealType: Double] = [:]
        for entry in entries {
            let meal = entry.meal
            meals[meal, default: 0] += entry.nutrition.calories
        }
        return .init(date: calendar.startOfDay(for: date), nutrition: entries.reduce(.zero) { $0 + $1.nutrition },
                     water: drinks.reduce(0) { $0 + $1.amount }, entryCount: entries.count,
                     produceCount: entries.filter { $0.category == .fruit || $0.category == .vegetable }.count,
                     mealCalories: meals)
    }

}
struct ReviewResult {
    let score: Double?
    let rating: String
    let messages: [String]
}
enum ReviewEngine {
    static func daily(_ stats: DailyStatistics, goals: ProfileDraft, complete: Bool) -> ReviewResult {
        guard stats.entryCount > 0 else {
            return .init(score: nil, rating: "No food logged", messages: ["Log what you ate to build a useful picture of your day. An empty diary is not a completed day."])
        }
        let ratio = stats.nutrition.calories / max(1, goals.calories)
        // Very low intake does not earn a high calorie score. Scores are logging feedback, not a medical assessment.
        let calorieScore = max(0, 1 - abs(ratio - 1) / 0.5) * 4
        let proteinScore = min(1, stats.nutrition.protein / max(1, goals.protein)) * 2
        let waterScore = min(1, stats.water / max(1, goals.water)) * 1.5
        let produceScore = min(1, Double(stats.produceCount) / 3) * 1.5
        let consistencyScore = min(1, Double(stats.mealsLogged) / 3)
        let score = min(10, max(0, calorieScore + proteinScore + waterScore + produceScore + consistencyScore))
        var messages: [String] = []
        if !complete { messages.append("Today's review is provisional. Keep logging as your day continues.") }
        if ratio < 0.75 {
            messages.append(complete ? "Your logged calories are well below your target. Check for missing entries and aim for enough food to support your day." : "You have room for more meals today.")
        } else if ratio <= 1.05 {
            messages.append("Your calorie intake is close to your target. Sustainable consistency matters more than exact numbers.")
        } else {
            messages.append("You logged above your calorie target. One day is part of a longer trend; continue your usual routine tomorrow.")
        }
        if stats.nutrition.protein >= goals.protein { messages.append("You reached your protein goal.") }
        else if stats.nutrition.protein >= goals.protein * 0.9 { messages.append("Your protein intake is close to your goal.") }
        else { messages.append("A protein source with your next meal can help you reach your goal.") }
        if stats.water < goals.water { messages.append("You have \(Int(max(0, goals.water - stats.water))) ml left toward your water goal. Spread drinking comfortably through the day.") }
        else { messages.append("You reached your water logging goal.") }
        if let largest = stats.mealCalories.max(by: { $0.value < $1.value }) { messages.append("Most of your logged calories came from \(largest.key.rawValue.lowercased()).") }
        if stats.produceCount < 3 { messages.append("Consider adding fruit or vegetables to a meal tomorrow. Mark their category when logging so your review can recognize them.") }
        if (stats.mealCalories[.snack] ?? 0) <= goals.calories * 0.2 { messages.append("Your snacks fit comfortably within your daily target.") }
        return .init(score: (score * 10).rounded() / 10,
                     rating: score >= 8 ? "Excellent" : score >= 6 ? "Good" : score >= 4 ? "Fair" : "Needs improvement", messages: messages)
    }
    static func streak(dates: [Date], today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
struct WeeklyReport {
    static func make(ending: Date, foods: [FoodLog], water: [WaterLog], calendar: Calendar = .current) -> Self {
        let dates = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: ending) }
        return .init(days: dates.map { DailyStatistics.calculate(date: $0, foods: foods, water: water, calendar: calendar) })
    }
    let days: [DailyStatistics]
    var loggedDays: [DailyStatistics] { days.filter { $0.entryCount > 0 } }
    var averageCalories: Double { average(\.calories) }
    var averageProtein: Double { average(\.protein) }
    private func average(_ keyPath: KeyPath<Nutrition, Double>) -> Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.nutrition[keyPath: keyPath] } / Double(loggedDays.count)
    }
    func calorieHits(goal: Double) -> Int { loggedDays.filter { abs($0.nutrition.calories - goal) <= goal * 0.1 }.count }
    func proteinHits(goal: Double) -> Int { loggedDays.filter { $0.nutrition.protein >= goal }.count }

    static func advice(measurements: [WeightSample], goal: Goal, loggedDays: Int, calendar: Calendar = .current) -> String {
        guard loggedDays >= 4 else { return "Log a few more days to make the weekly averages more useful. Missing days are excluded, rather than counted as zero intake." }
        let valid = measurements.filter { $0.weight != nil }.sorted { $0.date < $1.date }
        guard let first = valid.first, let last = valid.last, let start = first.weight, let end = last.weight,
              let dayCount = calendar.dateComponents([.day], from: first.date, to: last.date).day, dayCount >= 6 else {
            return "Keep logging meals and regular measurements. More measurements are needed to assess your weight trend."
        }
        let weeklyChange = (end - start) / Double(dayCount) * 7
        if goal == .lose && weeklyChange < -start * 0.01 { return "Your recorded weight is dropping quickly. Consider slightly increasing intake and discussing your target with a qualified professional. Short-term changes can also reflect water weight." }
        if goal == .lose && dayCount >= 21 && weeklyChange > -0.1 { return "Your recorded weight has been fairly stable for several weeks. Check logging completeness, then consider a small target adjustment or more activity. Keep your intake adequate." }
        if goal == .lose && weeklyChange < -0.1 { return "Your recorded trend is consistent with gradual weight loss. Continue your routine and watch the longer-term trend." }
        return "Keep a consistent routine and review your longer-term trend. Weight naturally fluctuates from day to day."
    }
}

struct WeightSample { var date: Date; var weight: Double? }

struct FoodLog {
    var date: Date
    var nutrition: Nutrition
    var meal: MealType
    var category: FoodCategory
}
struct WaterLog { var date: Date; var amount: Double }
