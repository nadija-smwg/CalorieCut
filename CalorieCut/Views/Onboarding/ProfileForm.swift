import SwiftUI

struct ProfileFields: View {
    @Environment(AppStore.self) private var store
    @Binding var draft: ProfileDraft
    var body: some View {
        Section("About you") {
            TextField("Name", text: $draft.name).textContentType(.givenName).accessibilityIdentifier("profileName")
            Stepper("Age: \(draft.age)", value: $draft.age, in: 18...100)
            Picker("Sex used for BMR", selection: $draft.sex) { ForEach(Sex.allCases) { Text($0.rawValue).tag($0) } }
            Text("These two equation options estimate energy needs; they are not a statement about gender identity.").font(.caption).foregroundStyle(.secondary)
            NumberField(title: "Height", value: lengthBinding($draft.height), unit: store.settings.lengthUnit)
            NumberField(title: "Current weight", value: weightBinding($draft.weight), unit: store.settings.weightUnit)
            NumberField(title: "Target weight", value: weightBinding($draft.targetWeight), unit: store.settings.weightUnit)
            NumberField(title: "Waist", value: lengthBinding($draft.waist), unit: store.settings.lengthUnit)
        }
        Section("Your routine") {
            Picker("Activity", selection: $draft.activity) { ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) } }
            Text("Light activity includes regular walking, such as around 2 km a day. Estimates vary by person.").font(.caption).foregroundStyle(.secondary)
            Picker("Goal", selection: $draft.goal) { ForEach(Goal.allCases) { Text($0.rawValue).tag($0) } }
            if draft.goal != .maintain {
                NumberField(title: "Weekly change", value: $draft.weeklyChange, unit: "kg/week")
                Text("Choose a gradual change, typically 0.25–0.5 kg per week. Suggestions cap the deficit to keep it moderate.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func weightBinding(_ binding: Binding<Double>) -> Binding<Double> {
        Binding(get: { Units.weight(binding.wrappedValue, unit: store.settings.weightUnit) },
                set: { binding.wrappedValue = Units.kilograms($0, unit: store.settings.weightUnit) })
    }
    private func lengthBinding(_ binding: Binding<Double>) -> Binding<Double> {
        Binding(get: { Units.length(binding.wrappedValue, unit: store.settings.lengthUnit) },
                set: { binding.wrappedValue = Units.centimeters($0, unit: store.settings.lengthUnit) })
    }
}
struct GoalFields: View {
    @Binding var draft: ProfileDraft
    private var suggestion: CalorieSuggestion { CalorieCalculator.suggestion(draft) }
    var body: some View {
        Section("Your estimated needs") {
            MetricRow(label: "BMR", value: "\(suggestion.bmr.whole) kcal")
            MetricRow(label: "Maintenance / TDEE", value: "\(suggestion.tdee.whole) kcal")
            MetricRow(label: "Suggested target", value: "\(suggestion.target.whole) kcal")
            Button("Use suggested calorie target") { draft.calories = suggestion.target }
            Text("Mifflin–St Jeor with an activity multiplier. These are estimates, not medical advice. Targets below \(Int(CalorieCalculator.minimum(sex: draft.sex))) kcal are not supported.").font(.caption).foregroundStyle(.secondary)
            if suggestion.adjustedForSafety {
                Label("Your requested change was moderated for adequate intake. Consider a slower goal and professional guidance if needed.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if draft.targetWeight / pow(draft.height / 100, 2) < 18.5 {
                Label("Your target weight is low relative to your height. Consider maintaining weight and seek qualified guidance before trying to lose weight.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
        }
        Section("Daily goals · editable") {
            NumberField(title: "Calories", value: $draft.calories, unit: "kcal")
            if draft.calories < CalorieCalculator.minimum(sex: draft.sex) * 1.1 {
                Label("This target is unusually low. Choose a more moderate intake and seek professional guidance before restricting further.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            NumberField(title: "Protein", value: $draft.protein, unit: "g")
            NumberField(title: "Carbohydrates", value: $draft.carbs, unit: "g")
            NumberField(title: "Fat", value: $draft.fat, unit: "g")
            NumberField(title: "Water", value: $draft.water, unit: "ml")
            Text("Macro goals are independent targets. Default protein is 120 g; a 110–125 g range is useful for the example profile. Adjust goals to your needs.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct ProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: ProfileDraft
    var body: some View {
        NavigationStack {
            Form { if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }; ProfileFields(draft: $draft); GoalFields(draft: $draft) }
                .navigationTitle("Profile & goals").navigationBarTitleDisplayMode(.inline)
                .keyboardDismissButton()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.saveProfile(draft) { Haptics.success(); dismiss() } } }
                }
        }
    }
}
