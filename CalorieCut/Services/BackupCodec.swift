import Foundation

struct BackupEnvelope: Codable {
    var version = 1
    var exportedAt = Date.now
    var profile: ProfileRecord?
    var foods: [FoodRecord]
    var entries: [EntryRecord]
    var meals: [MealRecord]
    var measurements: [MeasurementRecord]
    var water: [WaterRecord]
    var notes: [NoteRecord]
    var settings: SettingsRecord
}
struct ProfileRecord: Codable { var id: UUID; var createdAt: Date; var values: ProfileDraft }
struct FoodRecord: Codable {
    var id: UUID; var values: FoodDraft; var favorite: Bool; var sample: Bool; var createdAt: Date; var lastUsedAt: Date?
}
struct EntryRecord: Codable { var id: UUID; var createdAt: Date; var values: FoodDraft }
struct MealRecord: Codable { var id: UUID; var name: String; var createdAt: Date; var foods: [FoodDraft] }
struct MeasurementRecord: Codable { var id: UUID; var date: Date; var weight: Double?; var waist: Double?; var notes: String }
struct WaterRecord: Codable { var id: UUID; var date: Date; var amount: Double }
struct NoteRecord: Codable { var id: UUID; var date: Date; var text: String; var steps: Int }
struct SettingsRecord: Codable { var weightUnit: String; var lengthUnit: String; var theme: AppTheme; var reminders: [ReminderPreference] }

enum BackupCodec {
    static func decode(_ data: Data) throws -> BackupEnvelope {
        guard data.count <= 25_000_000 else { throw AppError.invalid("This backup is too large.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupEnvelope.self, from: data)
        try validate(backup)
        return backup
    }
    static func validate(_ backup: BackupEnvelope) throws {
        guard backup.version == 1 else { throw AppError.invalid("This backup version is not supported.") }
        guard backup.entries.count <= 100000, backup.foods.count <= 10000, backup.meals.count <= 5000,
              backup.measurements.count <= 50000, backup.water.count <= 100000, backup.notes.count <= 50000 else { throw AppError.invalid("The backup contains too many records.") }
        if let profile = backup.profile, let message = profile.values.validation { throw AppError.invalid(message) }
        var allIDs = backup.foods.map(\.id)
        allIDs += backup.entries.map(\.id)
        allIDs += backup.meals.map(\.id)
        allIDs += backup.measurements.map(\.id)
        allIDs += backup.water.map(\.id)
        allIDs += backup.notes.map(\.id)
        allIDs += backup.meals.flatMap { $0.foods.map(\.id) }
        guard Set(allIDs).count == allIDs.count else { throw AppError.invalid("The backup has duplicate record identifiers.") }
        var drafts = backup.entries.map(\.values)
        drafts += backup.foods.map(\.values)
        drafts += backup.meals.flatMap(\.foods)
        for draft in drafts {
            if let message = draft.validation { throw AppError.invalid("Invalid food in backup: \(message)") }
        }
        for meal in backup.meals {
            guard !meal.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !meal.foods.isEmpty, meal.foods.count <= 200 else { throw AppError.invalid("A saved meal in this backup is invalid.") }
        }
        for value in backup.measurements {
            guard value.weight != nil || value.waist != nil, value.date <= .now,
                  value.weight.map({ $0.isFinite && (30...350).contains($0) }) ?? true,
                  value.waist.map({ $0.isFinite && (30...250).contains($0) }) ?? true else { throw AppError.invalid("A measurement in this backup is invalid.") }
        }
        guard backup.water.allSatisfy({ $0.amount.isFinite && (1...3000).contains($0.amount) && $0.date <= .now }),
              backup.notes.allSatisfy({ (0...100000).contains($0.steps) && $0.date <= .now }),
              ["kg", "lb"].contains(backup.settings.weightUnit), ["cm", "in"].contains(backup.settings.lengthUnit) else { throw AppError.invalid("The backup contains invalid water, notes, or units.") }
        let reminderIDs = Set(ReminderPreference.defaults.map(\.id))
        guard backup.settings.reminders.count == reminderIDs.count,
              Set(backup.settings.reminders.map(\.id)) == reminderIDs,
              backup.settings.reminders.allSatisfy({ (0...23).contains($0.hour) && (0...59).contains($0.minute) }) else { throw AppError.invalid("The reminder preferences are invalid.") }
    }
    static func encode(_ backup: BackupEnvelope) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
}
