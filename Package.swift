// swift-tools-version: 5.9
import PackageDescription

// Tests the same Foundation calculation files compiled into the iOS app.
// SwiftUI, SwiftData integration, and UI tests run through the Xcode scheme.
let package = Package(
    name: "CalorieCutCalculations",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CalorieCut", targets: ["CalorieCut"])],
    targets: [
        .target(name: "CalorieCut", path: "CalorieCut", exclude: [
            "App", "Views", "ViewModels", "Components", "Resources", "Models/Models.swift",
            "Utilities/ModelAdapters.swift", "Services/BackupService.swift", "Services/NotificationService.swift", "Services/SampleFoods.swift"
        ], sources: ["Models/Enums.swift", "Utilities/Drafts.swift", "Utilities/Formatting.swift", "Services/NutritionEngine.swift", "Services/BackupCodec.swift"]),
        .testTarget(name: "CalorieCutTests", dependencies: ["CalorieCut"], path: "CalorieCutTests", exclude: ["PersistenceTests.swift", "NotificationTests.swift"])
    ]
)
