import SwiftUI

struct DailyNoteEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var text = ""
    @State private var steps = 0
    var body: some View {
        NavigationStack {
            Form {
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
                Section("Daily reflection") {
                    TextEditor(text: $text).frame(minHeight: 170).accessibilityLabel("Daily note")
                    Text("Hunger, energy, a longer walk, or a meal with friends — anything you'd like to remember.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Activity") { TextField("Steps", value: $steps, format: .number).keyboardType(.numberPad) }
            }.navigationTitle(date.dayTitle).navigationBarTitleDisplayMode(.inline).keyboardDismissButton()
                .onAppear { text = store.note(on: date)?.text ?? ""; steps = store.note(on: date)?.steps ?? 0 }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.saveNote(date: date, text: text, steps: steps) { Haptics.success(); dismiss() } } }
                }
        }
    }
}
