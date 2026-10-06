import SwiftUI

struct FoodEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: FoodDraft
    var editingEntry: FoodEntry? = nil
    var editingFood: FoodItem? = nil
    var sourceFood: FoodItem? = nil
    var libraryOnly = false
    var componentSave: ((FoodDraft) -> Void)? = nil
    var onSaved: (() -> Void)? = nil
    @State private var reusable = false
    var body: some View {
        NavigationStack {
            Form {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section("Food") {
                    TextField("Food name", text: $draft.name).textInputAutocapitalization(.words).accessibilityIdentifier("foodName")
                    TextField("Serving description", text: $draft.serving)
                    if !libraryOnly { NumberField(title: "Quantity", value: $draft.quantity, unit: "servings") }
                    Picker("Category", selection: $draft.category) { ForEach(FoodCategory.allCases) { Text($0.rawValue).tag($0) } }
                }
                Section {
                    NumberField(title: "Calories", value: $draft.calories, unit: "kcal")
                    NumberField(title: "Protein", value: $draft.protein, unit: "g")
                    NumberField(title: "Carbohydrates", value: $draft.carbs, unit: "g")
                    NumberField(title: "Fat", value: $draft.fat, unit: "g")
                } header: { Text("Nutrition per ONE serving") } footer: {
                    Text("Quantity multiplies these values. For example, a serving described as ‘2 pieces’ with quantity 1 logs those 2 pieces. Calories may differ from macro estimates due to fiber and rounding.")
                }
                if !libraryOnly && componentSave == nil {
                    Section("Log to") {
                        Picker("Meal", selection: $draft.meal) { ForEach(MealType.allCases) { Text($0.rawValue).tag($0) } }
                        DatePicker("Date & time", selection: $draft.date, in: ...Date.now)
                        if editingEntry == nil && sourceFood == nil { Toggle("Save as reusable food", isOn: $reusable) }
                    }
                }
                Section("Total for this entry") {
                    MetricRow(label: "Calories", value: "\(draft.nutrition.calories.whole) kcal")
                    MetricRow(label: "Protein", value: "\(draft.nutrition.protein.decimal) g")
                    MetricRow(label: "Carbs / fat", value: "\(draft.nutrition.carbs.decimal) / \(draft.nutrition.fat.decimal) g")
                    if sourceFood?.isSample == true || editingFood?.isSample == true {
                        Label("Approximate sample values. Check your portion and edit as needed.", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle(libraryOnly ? "Reusable food" : editingEntry == nil ? "Add food" : "Edit food")
                .navigationBarTitleDisplayMode(.inline).keyboardDismissButton()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.semibold).accessibilityIdentifier("saveFood") }
                }
        }
    }
    private func save() {
        if let error = draft.validation { store.errorMessage = error; return }
        let success: Bool
        if let componentSave { componentSave(draft); success = true }
        else if libraryOnly { success = store.saveLibraryFood(draft, editing: editingFood) }
        else { success = store.saveFood(draft, editing: editingEntry, reusable: reusable, source: sourceFood) }
        if success { Haptics.success(); if let onSaved { onSaved() } else { dismiss() } }
    }
}
