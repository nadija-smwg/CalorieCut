import SwiftUI

struct CalendarScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    @State private var month = Date.now
    private let calendar = Calendar.current
    private var monthStart: Date { calendar.dateInterval(of: .month, for: month)?.start ?? month.startOfDay }
    private var leadingDays: Int { (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7 }
    private var dayCount: Int { calendar.range(of: .day, in: .month, for: month)?.count ?? 30 }
    private var weekdayNames: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").padding(12) }.accessibilityLabel("Previous month")
                        Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.title3.bold()); Spacer()
                        Button { changeMonth(1) } label: { Image(systemName: "chevron.right").padding(12) }
                            .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month)).accessibilityLabel("Next month")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                        ForEach(0..<7, id: \.self) { index in Text(weekdayNames[index]).font(.caption).foregroundStyle(.secondary) }
                        ForEach(0..<(leadingDays + dayCount), id: \.self) { index in
                            if index < leadingDays { Color.clear.frame(height: 44) }
                            else if let day = calendar.date(byAdding: .day, value: index - leadingDays, to: monthStart) {
                                let status = status(on: day)
                                Button { selectedDate = min(.now, day); dismiss() } label: {
                                    VStack(spacing: 4) {
                                        Text("\(calendar.component(.day, from: day))").font(.subheadline.weight(calendar.isDateInToday(day) ? .bold : .regular))
                                        Circle().fill(status.color).frame(width: 6, height: 6)
                                    }.frame(maxWidth: .infinity, minHeight: 44)
                                        .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Palette.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).disabled(day.startOfDay > Date.now.startOfDay)
                                    .accessibilityLabel("\(day.dayTitle), \(status.label)")
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            legend("Near goal (within 10%)", color: Palette.accent)
                            legend("Close or below target", color: .orange)
                            legend("More than 25% above target", color: .red)
                            legend("No food logged", color: .gray)
                            Text("Colors use your current calorie target. A partial diary may not represent your full day. Tap a date to view its entries.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(20)
            }.background(Palette.background).navigationTitle("Your calendar").navigationBarTitleDisplayMode(.inline)
                .onAppear { month = selectedDate }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func changeMonth(_ delta: Int) { month = calendar.date(byAdding: .month, value: delta, to: monthStart) ?? month }
    private func status(on date: Date) -> (color: Color, label: String) {
        let stats = store.stats(on: date)
        guard stats.entryCount > 0 else { return (.gray, "No food logged") }
        let ratio = stats.nutrition.calories / max(1, store.goals.calories)
        if (0.9...1.1).contains(ratio) { return (Palette.accent, "Near calorie goal") }
        if ratio > 1.25 { return (.red, "Significantly above calorie target") }
        return (.orange, "Close or below calorie target")
    }
    private func legend(_ text: String, color: Color) -> some View { HStack { Circle().fill(color).frame(width: 10, height: 10); Text(text).font(.subheadline) } }
}
