import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
@MainActor enum BackupService {
    static func envelope(store: AppStore) -> BackupEnvelope {
        .init(profile: store.profile.map { .init(id: $0.id, createdAt: $0.createdAt, values: ProfileDraft($0)) },
              foods: store.foods.map { .init(id: $0.id, values: FoodDraft($0, meal: .breakfast, date: .now), favorite: $0.isFavorite, sample: $0.isSample, createdAt: $0.createdAt, lastUsedAt: $0.lastUsedAt) },
              entries: store.entries.map { .init(id: $0.id, createdAt: $0.createdAt, values: FoodDraft($0)) },
              meals: store.meals.map { .init(id: $0.id, name: $0.name, createdAt: $0.createdAt, foods: $0.foods.map { part in var draft = FoodDraft(part, meal: .breakfast, date: .now); draft.id = part.id; return draft }) },
              measurements: store.measurements.map { .init(id: $0.id, date: $0.date, weight: $0.weight, waist: $0.waist, notes: $0.notes) },
              water: store.water.map { .init(id: $0.id, date: $0.date, amount: $0.amount) },
              notes: store.notes.map { .init(id: $0.id, date: $0.date, text: $0.text, steps: $0.steps) },
              settings: .init(weightUnit: store.settings.weightUnit, lengthUnit: store.settings.lengthUnit,
                              theme: AppTheme(rawValue: store.settings.theme) ?? .system, reminders: store.settings.reminders))
    }
    static func export(store: AppStore) throws -> Data {
        try BackupCodec.encode(envelope(store: store))
    }
    static func read(_ url: URL) throws -> BackupEnvelope {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 25_000_000 else { throw AppError.invalid("Backup files must be smaller than 25 MB.") }
        return try decode(Data(contentsOf: url))
    }


    static func decode(_ data: Data) throws -> BackupEnvelope { try BackupCodec.decode(data) }
    static func validate(_ backup: BackupEnvelope) throws { try BackupCodec.validate(backup) }
    // Replacement is a single SwiftData save. A failed save rolls back instead of erasing the old diary.
    static func restore(_ backup: BackupEnvelope, store: AppStore) -> Bool {
        let success = store.perform {
            try validate(backup)
            // Fresh internal IDs avoid unique-attribute upserts against deleted objects.
            // Owned meal snapshots are rebuilt together; no external record references exist.
            for item in store.entries { store.context.delete(item) }; for item in store.foods { store.context.delete(item) }
            for item in store.meals { store.context.delete(item) }; for item in store.measurements { store.context.delete(item) }
            for item in store.water { store.context.delete(item) }; for item in store.notes { store.context.delete(item) }
            if let item = store.profile { store.context.delete(item) }
            if let record = backup.profile { store.context.insert(UserProfile(draft: record.values, createdAt: record.createdAt)) }
            for record in backup.foods {
                let d = record.values
                let item = FoodItem(name: d.name, serving: d.serving, calories: d.calories, protein: d.protein, carbs: d.carbs, fat: d.fat, category: d.category, isSample: record.sample)
                item.isFavorite = record.favorite; item.createdAt = record.createdAt
                item.lastUsedAt = record.lastUsedAt; store.context.insert(item)
            }
            for record in backup.entries {
                let item = FoodEntry(draft: record.values); item.createdAt = record.createdAt; store.context.insert(item)
            }
            for record in backup.meals {
                let parts = record.foods.map { d in let item = SavedMealFood(draft: d); return item }
                let item = SavedMeal(name: record.name, foods: parts); item.createdAt = record.createdAt; store.context.insert(item)
            }
            for record in backup.measurements {
                let item = WeightEntry(date: record.date, weight: record.weight, waist: record.waist, notes: record.notes); store.context.insert(item)
            }
            for record in backup.water { let item = WaterEntry(date: record.date, amount: record.amount); store.context.insert(item) }
            for record in backup.notes { let item = DailyNote(date: record.date, text: record.text, steps: record.steps); store.context.insert(item) }
            store.settings.weightUnit = backup.settings.weightUnit; store.settings.lengthUnit = backup.settings.lengthUnit
            store.settings.theme = backup.settings.theme.rawValue
            store.settings.reminders = backup.settings.reminders.map { var value = $0; value.enabled = false; return value }
        }
        if success { store.notifications.cancelAll(); store.notice = "Backup restored. Reminder times were restored; enable reminders again when ready." }
        return success
    }
    static func shareURL(store: AppStore) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CalorieCut-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))).json")
        try export(store: store).write(to: url, options: .atomic)
        return url
    }
}
