import SwiftUI

struct FoodPicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var meal: MealType
    var date: Date
    private var logDate: Date { date.loggingTime }
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var tab = 0
    @State private var draft: FoodDraft?
    @State private var source: FoodItem?
    @State private var libraryOnly = false
    @State private var editingLibrary: FoodItem?
    @State private var showComposer = false
    @State private var editingMeal: SavedMeal?
    private var filtered: [FoodItem] {
        store.foods.filter { (!favoritesOnly || $0.isFavorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            .sorted {
                if $0.lastUsedAt != $1.lastUsedAt { return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
    var body: some View {
        NavigationStack {
            List {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section {
                    Picker("Add from", selection: $tab) { Text("Quick add").tag(0); Text("Saved meals").tag(1) }.pickerStyle(.segmented)
                    Button { source = nil; editingLibrary = nil; libraryOnly = false; draft = FoodDraft(meal: meal, date: logDate) } label: { Label("Add food manually", systemImage: "square.and.pencil") }
                }
                if tab == 0 {
                    Section {
                        Toggle("Favorites only", isOn: $favoritesOnly)
                        ForEach(filtered) { food in
                            HStack(spacing: 12) {
                                Button { store.favorite(food) } label: { Image(systemName: food.isFavorite ? "star.fill" : "star").foregroundStyle(food.isFavorite ? .orange : .secondary) }
                                    .buttonStyle(.borderless).accessibilityLabel(food.isFavorite ? "Unfavorite \(food.name)" : "Favorite \(food.name)")
                                Button {
                                    source = food; editingLibrary = nil; libraryOnly = false
                                    draft = FoodDraft(food, meal: meal, date: logDate)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(food.name).foregroundStyle(.primary).fontWeight(.medium)
                                        Text("\(food.defaultServing) · \(food.calories.whole) kcal").font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                                Button {
                                    if store.saveFood(FoodDraft(food, meal: meal, date: logDate), source: food) { Haptics.success(); dismiss() }
                                } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                                    .buttonStyle(.borderless).accessibilityLabel("Quick add one serving of \(food.name)")
                            }.contextMenu {
                                Button("Edit reusable food", systemImage: "pencil") {
                                    source = nil; editingLibrary = food; libraryOnly = true; draft = FoodDraft(food, meal: meal, date: logDate)
                                }
                                Button("Delete reusable food", systemImage: "trash", role: .destructive) { store.delete(food) }
                            }
                        }
                        if filtered.isEmpty { Text("No foods found. Add a reusable food below.").foregroundStyle(.secondary) }
                        Button("Create reusable food", systemImage: "plus") {
                            source = nil; editingLibrary = nil; libraryOnly = true; draft = FoodDraft(meal: meal, date: logDate)
                        }
                    } header: { Text("Recently used first") } footer: { Text("Sample foods contain approximate, editable nutrition. Tap + to add one serving, or tap a food to adjust its quantity.") }
                } else {
                    Section("Reusable meals") {
                        ForEach(store.meals.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { saved in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(saved.name).fontWeight(.medium)
                                    Text("\(saved.foods.count) foods · \(saved.nutrition.calories.whole) kcal · \(saved.nutrition.protein.whole) g protein").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { if store.addMeal(saved, to: meal, date: logDate) { Haptics.success(); dismiss() } } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                                    .buttonStyle(.borderless).accessibilityLabel("Add \(saved.name)")
                            }.contextMenu {
                                Button("Edit meal", systemImage: "pencil") { editingMeal = saved; showComposer = true }
                                Button("Delete meal", systemImage: "trash", role: .destructive) { store.delete(saved) }
                            }
                        }
                        if store.meals.isEmpty { Text("Save a combination of foods to add it with one tap.").foregroundStyle(.secondary) }
                        Button("Create a saved meal", systemImage: "plus") { editingMeal = nil; showComposer = true }
                    }
                }
            }.searchable(text: $search, prompt: "Search your foods and meals")
                .navigationTitle("Add to \(meal.rawValue.lowercased())").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $draft) { value in
                    FoodEditor(draft: value, editingFood: editingLibrary, sourceFood: source, libraryOnly: libraryOnly,
                               onSaved: libraryOnly ? nil : { dismiss() })
                }
                .sheet(isPresented: $showComposer) { MealComposer(editing: editingMeal) }
        }
    }
}
