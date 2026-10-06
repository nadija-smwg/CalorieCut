import SwiftUI
import UIKit

struct ReminderSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reminders = ReminderPreference.defaults
    @State private var saving = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reminders are optional and repeat daily at your chosen local time. Permission is requested only when you enable a reminder.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach($reminders) { $reminder in
                    Section {
                        Toggle("\(reminder.title) reminder", isOn: $reminder.enabled)
                        DatePicker("Time", selection: timeBinding(for: $reminder), displayedComponents: .hourAndMinute)
                            .disabled(!reminder.enabled)
                    }
                }
                Section {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iPhone notification settings", destination: url)
                    }
                }
                if let message = store.errorMessage { Section { Text(message).foregroundStyle(.red) } }
            }.disabled(saving).navigationTitle("Reminders").navigationBarTitleDisplayMode(.inline)
                .onAppear { reminders = store.settings.reminders }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) {
                        if saving { ProgressView() }
                        else { Button("Save") {
                            saving = true
                            Task { if await store.setReminders(reminders) { Haptics.success(); dismiss() }; saving = false }
                        } }
                    }
                }
        }
    }
    private func timeBinding(for reminder: Binding<ReminderPreference>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: reminder.wrappedValue.hour, minute: reminder.wrappedValue.minute, second: 0, of: .now) ?? .now
        }, set: {
            let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
            reminder.wrappedValue.hour = components.hour ?? 8; reminder.wrappedValue.minute = components.minute ?? 0
        })
    }
}
