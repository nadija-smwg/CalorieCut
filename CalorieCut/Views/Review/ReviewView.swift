import SwiftUI

struct ReviewView: View {
    @State private var date = Date.now
    @State private var selection = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DayPicker(date: $date)
                    Picker("Review period", selection: $selection) { Text("Daily").tag(0); Text("Weekly").tag(1) }.pickerStyle(.segmented)
                    if selection == 0 { DailyReviewContent(date: date) } else { WeeklyReviewContent(ending: date) }
                }.padding(20)
            }.background(Palette.background).navigationTitle("Review")
        }
    }
}
struct DailyReviewDetail: View {
    let date: Date
    var body: some View {
        ScrollView { DailyReviewContent(date: date).padding(20) }.background(Palette.background)
            .navigationTitle("Daily review").navigationBarTitleDisplayMode(.inline)
    }
}
struct DailyReviewContent: View {
    @Environment(AppStore.self) private var store
    let date: Date
    private var stats: DailyStatistics { store.stats(on: date) }
    private var result: ReviewResult { ReviewEngine.daily(stats, goals: store.goals, complete: date.startOfDay < Date.now.startOfDay) }
    var body: some View {
        VStack(spacing: 20) {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Text(date.dayTitle).font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Calendar.current.isDateInToday(date) ? "Today's score · provisional" : "Daily consistency score").font(.subheadline)
                            Text(result.score.map { "\($0.decimal) / 10" } ?? "—").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text(result.rating).foregroundStyle(Palette.accent).font(.headline)
                        }
                        Spacer(); Image(systemName: "checkmark.seal.fill").font(.system(size: 46)).foregroundStyle(Palette.accent.opacity(0.7)).accessibilityHidden(true)
                    }
                    Text("A reflection on logged calories, protein, water, produce, and meal consistency. This score is not a health assessment and incomplete logs affect it.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(spacing: 14) {
                    SectionTitle(title: "Daily nutrition")
                    MetricRow(label: "Calories", value: "\(stats.nutrition.calories.whole) / \(store.goals.calories.whole) kcal")
                    MetricRow(label: "Protein", value: "\(stats.nutrition.protein.decimal) / \(store.goals.protein.whole) g")
                    MetricRow(label: "Carbohydrates", value: "\(stats.nutrition.carbs.decimal) / \(store.goals.carbs.whole) g")
                    MetricRow(label: "Fat", value: "\(stats.nutrition.fat.decimal) / \(store.goals.fat.whole) g")
                    MetricRow(label: "Water", value: "\((stats.water / 1000).decimal) / \((store.goals.water / 1000).decimal) L")
                    Divider()
                    ForEach(MealType.allCases) { meal in MetricRow(label: meal.rawValue, value: "\((stats.mealCalories[meal] ?? 0).whole) kcal") }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "A moment to reflect", subtitle: "Created on your iPhone from simple rules")
                    ForEach(Array(result.messages.enumerated()), id: \.offset) { _, message in
                        HStack(alignment: .top, spacing: 10) { Image(systemName: "leaf").foregroundStyle(Palette.accent); Text(message).font(.subheadline) }
                    }
                    if let note = store.note(on: date), !note.text.isEmpty { Divider(); Text("Your note").font(.headline); Text(note.text).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
        }
    }
}
struct WeeklyReviewContent: View {
    @Environment(AppStore.self) private var store
    let ending: Date
    private var report: WeeklyReport { .make(ending: ending, foods: store.entries, water: store.water) }
    private var measurements: [WeightEntry] { store.measurements.filter { $0.date.startOfDay >= ending.dayOffset(-6).startOfDay && $0.date.startOfDay <= ending.startOfDay } }
    var body: some View {
        VStack(spacing: 20) {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "Your week", subtitle: "\(ending.dayOffset(-6).formatted(date: .abbreviated, time: .omitted)) – \(ending.formatted(date: .abbreviated, time: .omitted))")
                    MetricRow(label: "Logged days", value: "\(report.loggedDays.count) / 7")
                    MetricRow(label: "Average calories", value: "\(report.averageCalories.whole) kcal/day")
                    MetricRow(label: "Current calorie goal", value: "\(store.goals.calories.whole) kcal/day")
                    MetricRow(label: "Average protein", value: "\(report.averageProtein.decimal) g/day")
                    MetricRow(label: "Near calorie goal (±10%)", value: "\(report.calorieHits(goal: store.goals.calories)) / 7 days")
                    MetricRow(label: "Protein goal reached", value: "\(report.proteinHits(goal: store.goals.protein)) / 7 days")
                    Text("Averages include logged days only. Today may still be incomplete. Comparisons use your current goals.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "Measurement changes")
                    measurementChange(title: "Weight", values: measurements.compactMap(\.weight).map { Units.weight($0, unit: store.settings.weightUnit) }, unit: store.settings.weightUnit)
                    Divider()
                    measurementChange(title: "Waist", values: measurements.compactMap(\.waist).map { Units.length($0, unit: store.settings.lengthUnit) }, unit: store.settings.lengthUnit)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Next week's focus", systemImage: "sparkles").font(.headline)
                    Text(WeeklyReport.advice(measurements: store.measurements.filter { $0.date.startOfDay >= ending.dayOffset(-27).startOfDay && $0.date.startOfDay <= ending.startOfDay },
                                             goal: store.goals.goal, loggedDays: report.loggedDays.count)).font(.subheadline)
                    Text("Based on up to four weeks of measurements. This is general guidance, not a diagnosis.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    @ViewBuilder private func measurementChange(title: String, values: [Double], unit: String) -> some View {
        if values.count >= 2, let first = values.first, let last = values.last {
            MetricRow(label: title, value: "\(first.decimal) → \(last.decimal) \(unit)")
            MetricRow(label: "Change", value: "\(last - first >= 0 ? "+" : "")\((last - first).decimal) \(unit)")
        } else { Text("Log at least two \(title.lowercased()) measurements in this week to compare.").font(.subheadline).foregroundStyle(.secondary) }
    }
}
