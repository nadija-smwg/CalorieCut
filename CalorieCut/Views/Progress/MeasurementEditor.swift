import SwiftUI

struct MeasurementEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var editing: WeightEntry? = nil
    @State private var date = Date.now
    @State private var weight = 65.0
    @State private var waist = 82.0
    @State private var logWeight = true
    @State private var logWaist = true
    @State private var notes = ""
    private var previousWeight: Double? { store.measurements.last(where: { $0.date < date && $0.id != editing?.id && $0.weight != nil })?.weight }
    private var previousWaist: Double? { store.measurements.last(where: { $0.date < date && $0.id != editing?.id && $0.waist != nil })?.waist }
    var body: some View {
        NavigationStack {
            Form {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section("Measurement") {
                    DatePicker("Date & time", selection: $date, in: ...Date.now)
                    Toggle("Log weight", isOn: $logWeight)
                    if logWeight {
                        NumberField(title: "Weight", value: $weight, unit: store.settings.weightUnit)
                        if let previousWeight { comparison(previous: Units.weight(previousWeight, unit: store.settings.weightUnit), current: weight, unit: store.settings.weightUnit) }
                    }
                    Toggle("Log waist", isOn: $logWaist)
                    if logWaist {
                        NumberField(title: "Waist", value: $waist, unit: store.settings.lengthUnit)
                        if let previousWaist { comparison(previous: Units.length(previousWaist, unit: store.settings.lengthUnit), current: waist, unit: store.settings.lengthUnit) }
                    }
                }
                Section("Optional note") { TextField("How did you measure?", text: $notes, axis: .vertical).lineLimit(3...6) }
                Section { Text("Measure under similar conditions to see a useful trend. Day-to-day weight changes often reflect water and digestion.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle(editing == nil ? "Add measurement" : "Edit measurement").navigationBarTitleDisplayMode(.inline).keyboardDismissButton()
                .onAppear {
                    date = editing?.date ?? .now
                    weight = Units.weight(editing?.weight ?? store.measurements.last(where: { $0.weight != nil })?.weight ?? store.goals.weight, unit: store.settings.weightUnit)
                    waist = Units.length(editing?.waist ?? store.measurements.last(where: { $0.waist != nil })?.waist ?? store.goals.waist, unit: store.settings.lengthUnit)
                    logWeight = editing == nil || editing?.weight != nil; logWaist = editing == nil || editing?.waist != nil
                    notes = editing?.notes ?? ""
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        if store.saveMeasurement(date: date,
                                                 weight: logWeight ? Units.kilograms(weight, unit: store.settings.weightUnit) : nil,
                                                 waist: logWaist ? Units.centimeters(waist, unit: store.settings.lengthUnit) : nil,
                                                 notes: notes, editing: editing) { Haptics.success(); dismiss() }
                    }.disabled(!logWeight && !logWaist) }
                }
        }
    }
    @ViewBuilder private func comparison(previous: Double, current: Double, unit: String) -> some View {
        MetricRow(label: "Previous", value: "\(previous.decimal) \(unit)")
        MetricRow(label: "Current", value: "\(current.decimal) \(unit)")
        MetricRow(label: "Change", value: "\(current - previous >= 0 ? "+" : "")\((current - previous).decimal) \(unit)")
    }
}
