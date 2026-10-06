import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var now = Date.now
    @State private var showWater = false
    @State private var showMeasurement = false
    @State private var showNote = false
    private var stats: DailyStatistics { store.stats(on: now) }
    private var review: ReviewResult { ReviewEngine.daily(stats, goals: store.goals, complete: false) }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
    private var todaysWeight: String {
        guard let weight = store.measurements.last(where: { Calendar.current.isDateInToday($0.date) && $0.weight != nil })?.weight else { return "Add weight" }
        return "\(Units.weight(weight, unit: store.settings.weightUnit).decimal) \(store.settings.weightUnit)"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(greeting), \(store.profile?.name ?? "there")").font(.system(.title2, design: .rounded, weight: .bold))
                        Text(now.dayTitle).font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                    Card {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { CalorieRing(consumed: stats.nutrition.calories, goal: store.goals.calories); calorieDetails }
                            VStack(alignment: .center, spacing: 18) { CalorieRing(consumed: stats.nutrition.calories, goal: store.goals.calories); calorieDetails }
                        }
                        HStack(spacing: 16) {
                            MacroBar(title: "Protein", amount: stats.nutrition.protein, goal: store.goals.protein, color: Palette.protein)
                            MacroBar(title: "Carbs", amount: stats.nutrition.carbs, goal: store.goals.carbs, color: Palette.carbs)
                            MacroBar(title: "Fat", amount: stats.nutrition.fat, goal: store.goals.fat, color: Palette.fat)
                        }.padding(.top, 20)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Button { showWater = true } label: { StatTile(title: "Water · tap to log", value: "\((stats.water / 1000).decimal) / \((store.goals.water / 1000).decimal) L", icon: "drop.fill", color: .blue) }.buttonStyle(.plain)
                        Button { showMeasurement = true } label: { StatTile(title: "Today's weight", value: todaysWeight, icon: "scalemass.fill") }.buttonStyle(.plain)
                        StatTile(title: "Tracking streak", value: "\(store.streak) \(store.streak == 1 ? "day" : "days")", icon: "flame.fill", color: .orange)
                        NavigationLink { DailyReviewDetail(date: .now) } label: { StatTile(title: "Today's score · provisional", value: review.score.map { "\($0.decimal) / 10" } ?? "Start logging", icon: "checkmark.seal.fill", color: Palette.protein) }.buttonStyle(.plain)
                    }
                    HStack {
                        SectionTitle(title: "Today's meals", subtitle: "Small habits, steady progress")
                        Spacer()
                        Button { showNote = true } label: { Image(systemName: "square.and.pencil").font(.title3) }.accessibilityLabel("Edit daily note and steps")
                    }
                    ForEach(MealType.allCases) { meal in Card { MealSection(meal: meal, date: .now) } }
                    Card {
                        Button { showNote = true } label: {
                            HStack(alignment: .top) {
                                Image(systemName: "figure.walk").foregroundStyle(Palette.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(store.note(on: .now)?.steps ?? 0) steps").font(.headline)
                                    Text(store.note(on: .now)?.text.isEmpty == false ? store.note(on: .now)?.text ?? "" : "How did today feel? Add a note.").font(.subheadline).foregroundStyle(.secondary)
                                }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.foregroundStyle(.primary)
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }.background(Palette.background)
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
                .navigationTitle("CalorieCut").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showWater) { WaterTracker(date: .now) }
                .sheet(isPresented: $showMeasurement) { MeasurementEditor() }
                .sheet(isPresented: $showNote) { DailyNoteEditor(date: .now) }
        }
    }
    private var calorieDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily goal").font(.caption).foregroundStyle(.secondary)
            Text("\(store.goals.calories.whole) kcal").font(.headline)
            Divider()
            Text(stats.nutrition.calories <= store.goals.calories ? "Remaining" : "Above target").font(.caption).foregroundStyle(.secondary)
            Text(abs(store.goals.calories - stats.nutrition.calories).whole).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(stats.nutrition.calories > store.goals.calories ? .orange : Palette.accent)
            Text("kcal").font(.caption).foregroundStyle(.secondary)
        }.frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)
    }
}
