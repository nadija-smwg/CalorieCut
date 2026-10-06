import SwiftUI
import SwiftData

@main struct CalorieCutApp: App {
    @State private var store: AppStore?
    private let container: ModelContainer?
    private let startupError: String?
    init() {
        do {
            let schema = Schema([UserProfile.self, FoodItem.self, FoodEntry.self, SavedMeal.self,
                                 SavedMealFood.self, WeightEntry.self, WaterEntry.self, DailyNote.self, UserSettings.self])
            let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
            let config: ModelConfiguration
            if testing { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
            else {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("CalorieCut", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                       attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                var localDirectory = directory
                var values = URLResourceValues(); values.isExcludedFromBackup = true
                try localDirectory.setResourceValues(values)
                config = ModelConfiguration("CalorieCut", schema: schema, url: directory.appendingPathComponent("CalorieCut.store"), cloudKitDatabase: .none)
            }
            let value = try ModelContainer(for: schema, configurations: [config])
            let appStore = try AppStore(context: value.mainContext)
            container = value; startupError = nil
            _store = State(initialValue: appStore)
        } catch {
            container = nil; startupError = error.localizedDescription
            _store = State(initialValue: nil)
        }
    }
    var body: some Scene {
        WindowGroup {
            if let store, let container {
                RootView().environment(store).modelContainer(container)
                    .preferredColorScheme(store.settings.theme == "Dark" ? .dark : store.settings.theme == "Light" ? .light : nil)
            } else {
                ContentUnavailableView {
                    Label("Unable to open your diary", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your data has not been reset. Restart CalorieCut and check available iPhone storage.\n\n\(startupError ?? "Unknown storage error")")
                }
            }
        }
    }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Group {
            if store.profile == nil { OnboardingView() }
            else {
                TabView {
                    HomeView().tabItem { Label("Home", systemImage: "house.fill") }
                    DiaryView().tabItem { Label("Diary", systemImage: "book.closed.fill") }
                    ProgressViewScreen().tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                    ReviewView().tabItem { Label("Review", systemImage: "checkmark.seal.fill") }
                    SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            }
        }
        .tint(Palette.accent)
        .alert(store.errorMessage == nil ? "CalorieCut" : "Something needs attention",
               isPresented: Binding(get: { store.errorMessage != nil || store.notice != nil }, set: {
                   if !$0 { store.errorMessage = nil; store.notice = nil }
               })) {
            Button("OK") { store.errorMessage = nil; store.notice = nil }
        } message: { Text(store.errorMessage ?? store.notice ?? "") }
    }
}
