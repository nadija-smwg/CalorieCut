import SwiftUI

struct DiaryView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date.now
    @State private var showCalendar = false
    @State private var addingMeal: MealType?
    @State private var editing: FoodEntry?
    @State private var copying: FoodEntry?
    @State private var deleting: FoodEntry?
    @State private var showNote = false
    @State private var showWater = false
    private var stats: DailyStatistics { store.stats(on: date) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DayPicker(date: $date)
                    MetricRow(label: "Calories", value: "\(stats.nutrition.calories.whole) / \(store.goals.calories.whole) kcal")
                    HStack(spacing: 12) {
                        MacroBar(title: "Protein", amount: stats.nutrition.protein, goal: store.goals.protein, color: Palette.protein)
                        MacroBar(title: "Carbs", amount: stats.nutrition.carbs, goal: store.goals.carbs, color: Palette.carbs)
                        MacroBar(title: "Fat", amount: stats.nutrition.fat, goal: store.goals.fat, color: Palette.fat)
                    }.padding(.vertical, 5)
                }
                ForEach(MealType.allCases) { meal in
                    Section {
                        ForEach(store.foods(on: date, meal: meal)) { entry in
                            Button { editing = entry } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.foodName).fontWeight(.medium)
                                        Text("\(entry.quantity.decimal) × \(entry.serving)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Text("\(entry.nutrition.calories.whole) kcal").foregroundStyle(.secondary)
                                }.foregroundStyle(.primary)
                            }.swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { deleting = entry }
                                Button("Edit") { editing = entry }.tint(Palette.accent)
                            }.swipeActions(edge: .leading) { Button("Duplicate") { store.duplicate(entry) }.tint(.blue) }
                                .contextMenu {
                                    Button("Edit") { editing = entry }
                                    Button("Duplicate") { store.duplicate(entry) }
                                    Button("Copy to another day") { copying = entry }
                                    Menu("Move to meal") { ForEach(MealType.allCases) { value in Button(value.rawValue) { store.move(entry, to: value) } } }
                                    Button("Delete", role: .destructive) { deleting = entry }
                                }
                        }
                        Button { addingMeal = meal } label: { Label("Add food", systemImage: "plus") }
                    } header: {
                        HStack { Label(meal.rawValue, systemImage: meal.icon); Spacer(); Text("\(store.foods(on: date, meal: meal).reduce(0) { $0 + $1.nutrition.calories }.whole) kcal") }
                    }
                }
                Section("The rest of your day") {
                    Button { showWater = true } label: { MetricRow(label: "Water", value: "\((stats.water / 1000).decimal) L") }
                    Button { showNote = true } label: { Label("Notes & steps", systemImage: "square.and.pencil") }
                    if let note = store.note(on: date), !note.text.isEmpty { Text(note.text).font(.subheadline).foregroundStyle(.secondary) }
                    NavigationLink { DailyReviewDetail(date: date) } label: { Label("Review this day", systemImage: "checkmark.seal") }
                }
            }.navigationTitle("Diary")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCalendar = true } label: { Image(systemName: "calendar") }.accessibilityLabel("Open calendar") } }
                .sheet(isPresented: $showCalendar) { CalendarScreen(selectedDate: $date) }
                .sheet(item: $addingMeal) { FoodPicker(meal: $0, date: min(.now, date)) }
                .sheet(item: $editing) { FoodEditor(draft: FoodDraft($0), editingEntry: $0) }
                .sheet(item: $copying) { CopyFoodView(entry: $0) }
                .sheet(isPresented: $showNote) { DailyNoteEditor(date: date) }
                .sheet(isPresented: $showWater) { WaterTracker(date: date) }
                .confirmationDialog("Delete this food entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Delete entry", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
                }
        }
    }
}
