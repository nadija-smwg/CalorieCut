import SwiftUI

struct MealSection: View {
    @Environment(AppStore.self) private var store
    let meal: MealType
    let date: Date
    @State private var showAdd = false
    @State private var editing: FoodEntry?
    @State private var copying: FoodEntry?
    @State private var deleting: FoodEntry?
    private var entries: [FoodEntry] { store.foods(on: date, meal: meal) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(meal.rawValue, systemImage: meal.icon).font(.headline)
                Spacer()
                Text("\(entries.reduce(0) { $0 + $1.nutrition.calories }.whole) kcal").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            if entries.isEmpty { Text("Ready when you are.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.foodName).font(.subheadline.weight(.medium))
                        Text("\(entry.quantity.decimal) × \(entry.serving) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(entry.nutrition.calories.whole).font(.subheadline).monospacedDigit()
                    Menu {
                        entryActions(entry)
                    } label: { Image(systemName: "ellipsis.circle").padding(4) }.accessibilityLabel("Actions for \(entry.foodName)")
                }.contentShape(Rectangle()).onTapGesture { editing = entry }
                    .contextMenu { entryActions(entry) }
            }
            Button { showAdd = true } label: { Label("Add food", systemImage: "plus").font(.subheadline.weight(.semibold)) }
                .accessibilityLabel("Add food to \(meal.rawValue)")
        }.sheet(isPresented: $showAdd) { FoodPicker(meal: meal, date: min(.now, date)) }
            .sheet(item: $editing) { entry in FoodEditor(draft: FoodDraft(entry), editingEntry: entry) }
            .sheet(item: $copying) { entry in CopyFoodView(entry: entry) }
            .confirmationDialog("Delete this food entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete entry", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
            }
    }
    @ViewBuilder private func entryActions(_ entry: FoodEntry) -> some View {
        Button("Edit", systemImage: "pencil") { editing = entry }
        Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicate(entry) }
        Menu("Move to meal") { ForEach(MealType.allCases) { value in Button(value.rawValue) { store.move(entry, to: value) } } }
        Button("Copy to another day", systemImage: "calendar.badge.plus") { copying = entry }
        Button("Delete", systemImage: "trash", role: .destructive) { deleting = entry }
    }
}
struct CopyFoodView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry
    @State private var date = Date.now
    @State private var meal: MealType = .breakfast
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Copy \(entry.foodName)").font(.headline); DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                    Picker("Meal", selection: $meal) { ForEach(MealType.allCases) { Text($0.rawValue).tag($0) } }
                }
            }.navigationTitle("Copy food").navigationBarTitleDisplayMode(.inline)
                .onAppear { meal = MealType(rawValue: entry.mealType) ?? .breakfast }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Copy") {
                        var draft = FoodDraft(entry); draft.date = date.loggingTime; draft.meal = meal
                        if store.saveFood(draft) { Haptics.success(); dismiss() }
                    } }
                }
        }
    }
}
