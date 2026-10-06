import SwiftUI
import UIKit

enum Palette {
    static let accent = Color("AccentColor")
    static let protein = Color(red: 0.35, green: 0.40, blue: 0.84)
    static let carbs = Color.orange
    static let fat = Color.pink
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.035), radius: 10, y: 4)
    }
}
struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}
struct CalorieRing: View {
    let consumed: Double
    let goal: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(Palette.accent.opacity(0.12), lineWidth: 15)
            Circle().trim(from: 0, to: min(1, max(0, consumed / max(1, goal))))
                .stroke(consumed > goal ? Color.orange : Palette.accent, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: consumed)
            VStack(spacing: 3) {
                Text(consumed.whole).font(.system(.largeTitle, design: .rounded, weight: .bold)).minimumScaleFactor(0.6)
                Text("/ \(goal.whole) kcal").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.frame(width: 155, height: 155).padding(8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(consumed.whole) of \(goal.whole) calories consumed")
    }
}
struct MacroBar: View {
    let title: String
    let amount: Double
    let goal: Double
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold())
            ProgressView(value: min(1, amount / max(1, goal))).tint(color)
            Text("\(amount.whole) / \(goal.whole) g").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }
}
struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = Palette.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(.headline).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
    }
}
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String
    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                .accessibilityIdentifier(title)
            Text(unit).foregroundStyle(.secondary).font(.subheadline)
        }
    }
}
struct MetricRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.semibold).monospacedDigit() }
    }
}
struct DayPicker: View {
    @Binding var date: Date
    var body: some View {
        HStack {
            Button { date = date.dayOffset(-1) } label: { Image(systemName: "chevron.left").padding(8) }.accessibilityLabel("Previous day")
            Spacer()
            DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date).labelsHidden()
            Spacer()
            Button { date = min(.now, date.dayOffset(1)) } label: { Image(systemName: "chevron.right").padding(8) }
                .disabled(Calendar.current.isDateInToday(date)).accessibilityLabel("Next day")
        }
    }
}
enum Haptics { static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
extension View {
    func keyboardDismissButton() -> some View {
        toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
    }
}
