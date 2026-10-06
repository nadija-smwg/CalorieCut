import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showProfile = false
    @State private var showReminders = false
    @State private var showImport = false
    @State private var pendingBackup: BackupEnvelope?
    @State private var confirmImport = false
    @State private var confirmDelete = false
    @State private var share: ShareFile?
    @State private var exportDocument: BackupDocument?
    @State private var showExport = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile & goals") {
                    Button { showProfile = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(Palette.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.profile?.name ?? "Your profile").font(.headline).foregroundStyle(.primary)
                                Text("\(store.goals.goal.rawValue) · \(store.goals.calories.whole) kcal/day").font(.subheadline).foregroundStyle(.secondary)
                            }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    Text("Edit your age, height, activity, measurements, and nutrition targets.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Preferences") {
                    Picker("Weight unit", selection: Binding(get: { store.settings.weightUnit }, set: { store.savePreferences(weight: $0, length: store.settings.lengthUnit, theme: AppTheme(rawValue: store.settings.theme) ?? .system) })) {
                        Text("Kilograms (kg)").tag("kg"); Text("Pounds (lb)").tag("lb")
                    }
                    Picker("Length unit", selection: Binding(get: { store.settings.lengthUnit }, set: { store.savePreferences(weight: store.settings.weightUnit, length: $0, theme: AppTheme(rawValue: store.settings.theme) ?? .system) })) {
                        Text("Centimeters (cm)").tag("cm"); Text("Inches (in)").tag("in")
                    }
                    Picker("Appearance", selection: Binding(get: { AppTheme(rawValue: store.settings.theme) ?? .system }, set: { store.savePreferences(weight: store.settings.weightUnit, length: store.settings.lengthUnit, theme: $0) })) {
                        ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Notifications") {
                    Button { showReminders = true } label: { Label("Optional reminders", systemImage: "bell.badge") }
                    Text("All reminders are scheduled locally. Choose which reminders you want and when they arrive.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Your data") {
                    Button("Share JSON backup", systemImage: "square.and.arrow.up") {
                        do { share = ShareFile(url: try BackupService.shareURL(store: store)) }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("Save JSON backup to Files", systemImage: "folder") {
                        do { exportDocument = BackupDocument(data: try BackupService.export(store: store)); showExport = true }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("Import JSON backup", systemImage: "square.and.arrow.down") { showImport = true }
                    Button("Delete all data", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    Text("Data stays in this app's local database and is excluded from automatic device backups. Export regularly to keep a copy. Sharing to iCloud Drive or AirDrop is your choice; the app needs neither.").font(.caption).foregroundStyle(.secondary)
                }
                Section("About") {
                    MetricRow(label: "Version", value: "1.0.0 (1)")
                    Label("No account or internet required", systemImage: "lock.shield")
                    NavigationLink("How CalorieCut calculates") { AboutView() }
                }
            }.navigationTitle("Settings")
                .sheet(isPresented: $showProfile) { ProfileEditor(draft: store.goals) }
                .sheet(isPresented: $showReminders) { ReminderSettingsView() }
                .sheet(item: $share) { ActivityShareSheet(url: $0.url) }
                .fileExporter(isPresented: $showExport, document: exportDocument, contentType: .json, defaultFilename: "CalorieCut-backup") { result in
                    if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
                }
                .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
                    do { pendingBackup = try BackupService.read(try result.get()); confirmImport = true }
                    catch { store.errorMessage = "Couldn't import this backup: \(error.localizedDescription)" }
                }
                .confirmationDialog("Replace your diary with this backup?", isPresented: $confirmImport, titleVisibility: .visible) {
                    Button("Replace with backup", role: .destructive) { if let backup = pendingBackup { _ = BackupService.restore(backup, store: store) }; pendingBackup = nil }
                    Button("Cancel", role: .cancel) { pendingBackup = nil }
                } message: {
                    Text("This contains \(pendingBackup?.entries.count ?? 0) food entries and \(pendingBackup?.measurements.count ?? 0) measurements. Existing data will be replaced. Export a backup first if you want to keep it. Restored reminders start disabled.")
                }
                .confirmationDialog("Delete all CalorieCut data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete everything", role: .destructive) { _ = store.deleteAll() }
                } message: { Text("Your profile, diary, reusable foods, meals, measurements, and preferences will be removed. This cannot be undone without an exported backup.") }
        }
    }
}
struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
struct AboutView: View {
    var body: some View {
        List {
            Section("Energy estimates") {
                Text("BMR uses Mifflin–St Jeor: 10 × kg + 6.25 × cm − 5 × age, plus 5 for the male equation or minus 161 for the female equation.")
                Text("Activity multipliers: sedentary 1.2, light 1.375, moderate 1.55, very active 1.725. TDEE is BMR × multiplier.")
                Text("Requested weekly change uses an approximate 7,700 kcal per kg. Fat-loss suggestions cap deficits at 20% of TDEE or 500 kcal/day, whichever is smaller. Gain suggestions cap surpluses at 350 kcal/day. Targets are rounded to 10 kcal and never below 1,500 for the male equation or 1,200 for the female equation. These floors do not guarantee a target is suitable for everyone.")
            }
            Section("Reviews & trends") {
                Text("Scores allocate up to 4 points to proximity to the calorie goal, 2 to protein, 1.5 to water, 1.5 to three fruit/vegetable entries, and 1 to three logged meal categories. Low intake earns fewer calorie points. Categories and logging completeness influence the result.")
                Text("A tracking streak counts consecutive days with at least one food entry. You can still log today to extend a streak ending yesterday. It does not require hitting a goal.")
                Text("Weekly and monthly averages exclude unlogged days. Historical comparisons use your current goals. Weight advice uses up to four weeks of available measurements; daily weight fluctuations are normal.")
            }
            Section("Local & private") {
                Text("No analytics, ads, login, backend, or network API. The SwiftData store is local, CloudKit is disabled, and the store directory is excluded from device backups. JSON exports contain personal data; choose where to share them.")
                Text("Sample foods are approximate and editable. This app is for adults and is not a medical device. It cannot promise spot fat reduction or diagnose health conditions.")
            }
        }.navigationTitle("How it works").navigationBarTitleDisplayMode(.inline)
    }
}
