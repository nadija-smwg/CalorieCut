import SwiftUI

struct MealComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var editing: SavedMeal? = nil
    @State private var name = ""
    @State private var parts: [FoodDraft] = []
    @State private var draft: FoodDraft?
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section("Meal") { TextField("Meal name, e.g. My Breakfast", text: $name) }
                Section("Foods in this meal · tap to adjust") {
                    ForEach(parts) { part in
                        Button { draft = part } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(part.name); Text("\(part.quantity.decimal) × \(part.serving)").font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Text("\(part.nutrition.calories.whole) kcal").foregroundStyle(.secondary)
                            }.foregroundStyle(.primary)
                        }
                    }.onDelete { parts.remove(atOffsets: $0) }
                    MetricRow(label: "Total", value: "\(parts.reduce(Nutrition.zero) { $0 + $1.nutrition }.calories.whole) kcal")
                    MetricRow(label: "Protein", value: "\(parts.reduce(Nutrition.zero) { $0 + $1.nutrition }.protein.whole) g")
                }
                Section("Add ingredients") {
                    Button("Create an ingredient", systemImage: "plus") { draft = FoodDraft() }
                    ForEach(store.foods.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { food in
                        Button {
                            var value = FoodDraft(food, meal: .breakfast, date: .now); value.id = UUID(); parts.append(value)
                        } label: { HStack { Text(food.name); Spacer(); Image(systemName: "plus.circle") } }
                    }
                }
            }.searchable(text: $search, prompt: "Find an ingredient")
                .navigationTitle(editing == nil ? "Create meal" : "Edit meal").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.saveMeal(name: name, foods: parts, editing: editing) { Haptics.success(); dismiss() } }.disabled(parts.isEmpty || name.isEmpty) }
                }
                .onAppear {
                    if let editing, parts.isEmpty {
                        name = editing.name
                        parts = editing.foods.map { var value = FoodDraft($0, meal: .breakfast, date: .now); value.id = $0.id; return value }
                    }
                }
                .sheet(item: $draft) { value in
                    FoodEditor(draft: value, componentSave: { saved in
                        if let index = parts.firstIndex(where: { $0.id == saved.id }) { parts[index] = saved }
                        else { parts.append(saved) }
                    })
                }
        }
    }
}
