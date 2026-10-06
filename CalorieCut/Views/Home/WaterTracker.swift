import SwiftUI

struct WaterTracker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var custom = 250.0
    private var total: Double { store.stats(on: date).water }
    var body: some View {
        NavigationStack {
            List {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "drop.fill").font(.system(size: 48)).foregroundStyle(.blue)
                        Text("\((total / 1000).decimal) / \((store.goals.water / 1000).decimal) L").font(.title.bold())
                        ProgressView(value: min(1, total / max(1, store.goals.water))).tint(.blue)
                        HStack {
                            Button("+250 ml") { add(250) }.buttonStyle(.bordered)
                            Button("+500 ml") { add(500) }.buttonStyle(.bordered)
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical)
                }
                Section("Custom amount") {
                    NumberField(title: "Water", value: $custom, unit: "ml")
                    Button("Add water") { add(custom) }
                }
                Section("Logged water · swipe to remove") {
                    ForEach(store.water.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }) { entry in
                        HStack { Text("\(entry.amount.whole) ml"); Spacer(); Text(entry.date.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary) }
                            .swipeActions { Button("Delete", role: .destructive) { store.delete(entry) } }
                    }
                }
            }.navigationTitle("Water").navigationBarTitleDisplayMode(.inline).keyboardDismissButton()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func add(_ amount: Double) {
        if store.addWater(amount: amount, date: date.loggingTime) { Haptics.success() }
    }
}
