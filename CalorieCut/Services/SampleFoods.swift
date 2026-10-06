import Foundation

enum SampleFoods {
    static func make() -> [FoodItem] {
        [
            food("Milk Rice", "2 pieces", 400, 8, 55, 16, .grain),
            food("Plain Tea", "1 cup", 2, 0, 0.5, 0, .drink),
            food("Full Cream Milk", "170 ml", 110, 5.7, 8.2, 6.0, .dairy),
            food("Boiled Egg", "1 egg", 75, 6.3, 0.6, 5.3, .protein),
            food("Chicken Breast", "100 g cooked", 165, 31, 0, 3.6, .protein),
            food("Cooked White Rice", "1 cup", 200, 4.3, 44.5, 0.4, .grain),
            food("Dhal", "1 serving", 150, 9, 22, 3, .protein),
            food("Fish", "100 g cooked", 140, 24, 0, 5, .protein),
            food("Banana", "1 medium", 100, 1.3, 26, 0.3, .fruit),
            food("Apple", "1 medium", 95, 0.5, 25, 0.3, .fruit),
            food("Plain Yogurt", "150 g", 95, 8, 10, 3, .dairy),
            food("Bread", "1 slice", 80, 3, 15, 1, .grain),
            food("Roti", "1 medium", 150, 4, 26, 4, .grain),
            food("String Hoppers", "5 small", 180, 3, 40, 0.5, .grain)
        ]
    }
    private static func food(_ name: String, _ serving: String, _ kcal: Double, _ p: Double, _ c: Double, _ f: Double, _ category: FoodCategory) -> FoodItem {
        FoodItem(name: name, serving: serving, calories: kcal, protein: p, carbs: c, fat: f, category: category, isSample: true)
    }
}
