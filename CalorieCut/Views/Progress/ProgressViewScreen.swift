import SwiftUI
import Charts

enum ProgressRange: String, CaseIterable, Identifiable {
    case week = "7 Days", month = "30 Days", quarter = "3 Months", all = "All Time"
    var id: String { rawValue }
    var start: Date {
        switch self {
        case .week: Date.now.dayOffset(-6).startOfDay
        case .month: Date.now.dayOffset(-29).startOfDay
        case .quarter: (Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now).startOfDay
        case .all: .distantPast
        }
    }
}
struct ChartPoint: Identifiable {
    var id: UUID = UUID()
    var date: Date
    var value: Double
}
struct TrendChart: View {
    let title: String
    let unit: String
    let points: [ChartPoint]
    var target: Double? = nil
    var color: Color = Palette.accent
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: title, subtitle: unit)
                if points.isEmpty {
                    ContentUnavailableView("No data yet", systemImage: "chart.xyaxis.line", description: Text("Add entries to see your trend.")).frame(height: 170)
                } else {
                    Chart {
                        ForEach(points) { point in
                            LineMark(x: .value("Date", point.date), y: .value(title, point.value)).foregroundStyle(color)
                            PointMark(x: .value("Date", point.date), y: .value(title, point.value)).foregroundStyle(color)
                        }
                        if let target { RuleMark(y: .value("Goal", target)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4])) }
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .chartYScale(domain: .automatic(includesZero: title == "Calories" || title == "Protein"))
                    .frame(height: 190)
                    .accessibilityLabel("\(title) chart with \(points.count) recorded values")
                    if let first = points.first, let last = points.last {
                        MetricRow(label: "First → latest", value: "\(first.value.decimal) → \(last.value.decimal) \(unit)")
                    }
                    if target != nil { Text("Dashed line shows your current goal.").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }
}
struct ProgressViewScreen: View {
    @Environment(AppStore.self) private var store
    @State private var range: ProgressRange = .month
    @State private var addMeasurement = false
    @State private var showHistory = false
    private var measurements: [WeightEntry] { store.measurements.filter { $0.date >= range.start && $0.date <= .now } }
    private var days: [DailyStatistics] {
        let loggedDates = Set(store.entries.filter { $0.date >= range.start && $0.date <= .now }.map { $0.date.startOfDay })
        return loggedDates.sorted().map { store.stats(on: $0) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Time range", selection: $range) { ForEach(ProgressRange.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    Card {
                        VStack(spacing: 12) {
                            SectionTitle(title: "Your rhythm", subtitle: "Averages across \(days.count) logged days")
                            MetricRow(label: "Calories", value: "\(average(\.calories).whole) kcal/day")
                            MetricRow(label: "Protein", value: "\(average(\.protein).decimal) g/day")
                            Text("Missing days are excluded. Charts show recorded values; goals use your current settings.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TrendChart(title: "Weight", unit: store.settings.weightUnit,
                               points: measurements.compactMap { entry in entry.weight.map { ChartPoint(date: entry.date, value: Units.weight($0, unit: store.settings.weightUnit)) } },
                               target: Units.weight(store.goals.targetWeight, unit: store.settings.weightUnit))
                    TrendChart(title: "Waist", unit: store.settings.lengthUnit,
                               points: measurements.compactMap { entry in entry.waist.map { ChartPoint(date: entry.date, value: Units.length($0, unit: store.settings.lengthUnit)) } }, color: .orange)
                    TrendChart(title: "Calories", unit: "kcal/day", points: days.map { ChartPoint(date: $0.date, value: $0.nutrition.calories) }, target: store.goals.calories)
                    TrendChart(title: "Protein", unit: "g/day", points: days.map { ChartPoint(date: $0.date, value: $0.nutrition.protein) }, target: store.goals.protein, color: Palette.protein)
                    Button("View measurement history", systemImage: "list.bullet") { showHistory = true }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                }.padding(20)
            }.background(Palette.background).navigationTitle("Progress")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { addMeasurement = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add measurement") } }
                .sheet(isPresented: $addMeasurement) { MeasurementEditor() }
                .sheet(isPresented: $showHistory) { MeasurementHistory() }
        }
    }
    private func average(_ keyPath: KeyPath<Nutrition, Double>) -> Double {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.nutrition[keyPath: keyPath] } / Double(days.count)
    }
}
struct MeasurementHistory: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: WeightEntry?
    @State private var adding = false
    @State private var deleting: WeightEntry?
    var body: some View {
        NavigationStack {
            List {
                if store.measurements.isEmpty { ContentUnavailableView("No measurements yet", systemImage: "scalemass", description: Text("Add your first weight or waist measurement.")) }
                ForEach(store.measurements.reversed()) { entry in
                    Button { editing = entry } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date.dayTitle).font(.headline)
                            HStack {
                                if let weight = entry.weight { Text("\(Units.weight(weight, unit: store.settings.weightUnit).decimal) \(store.settings.weightUnit)") }
                                if let waist = entry.waist { Text("Waist \(Units.length(waist, unit: store.settings.lengthUnit).decimal) \(store.settings.lengthUnit)") }
                            }.font(.subheadline).foregroundStyle(.secondary)
                            if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundStyle(.secondary) }
                        }.foregroundStyle(.primary)
                    }.swipeActions { Button("Delete", role: .destructive) { deleting = entry } }
                }
            }.navigationTitle("Measurements").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button { adding = true } label: { Image(systemName: "plus") } }
                }
                .sheet(item: $editing) { MeasurementEditor(editing: $0) }
                .sheet(isPresented: $adding) { MeasurementEditor() }
                .confirmationDialog("Delete this measurement?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
                }
        }
    }
}
