import Foundation
import os
import SwiftData

enum InventoryModelContainerStartupResult {
    case success(ModelContainer)
    case failure(InventoryModelContainerStartupError)
}

struct InventoryModelContainerStartupError: Error {
    let underlyingError: any Error
}

enum InventoryModelContainer {
    private static let startupLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HomeStuffInventoryApp",
        category: "PersistentStoreStartup"
    )

    @MainActor
    static func loadLive(
        makePersistentContainer: @escaping () throws -> ModelContainer = { try InventoryModelContainer.make() },
        recoverPendingRestore: @escaping (ModelContainer) throws -> Void = { container in
            try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: container)
        },
        runMaintenance: @escaping (ModelContainer) throws -> Void = { container in
            try InventoryModelContainer.runMaintenance(on: container)
        },
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> InventoryModelContainerStartupResult {
        do {
            #if DEBUG
            if ManagedValueRowRegressionConfiguration.isEnabled {
                return .success(try makeManagedValueRowRegressionSample())
            }
            if AppStoreDemoDataConfiguration.isEnabled(arguments: arguments) {
                guard let locale = AppStoreDemoDataConfiguration.requestedLocale(arguments: arguments) else {
                    throw AppStoreDemoDataConfigurationError.invalidLocale
                }
                return .success(try makeAppStoreDemo(locale: locale))
            }
            if SampleDataConfiguration.isEnabled {
                return .success(try makeSample(inMemory: true))
            }
            if arguments.contains("--qa-empty-inventory-store") {
                return .success(try make(inMemory: true))
            }
            #endif

            let container = try makePersistentContainer()
            try recoverPendingRestore(container)
            do {
                try runMaintenance(container)
            } catch {
                startupLogger.error("Persistent-store maintenance failed: \(error.localizedDescription, privacy: .private)")
            }
            return .success(container)
        } catch {
            startupLogger.error("Persistent-store startup failed: \(error.localizedDescription, privacy: .private)")
            return .failure(InventoryModelContainerStartupError(underlyingError: error))
        }
    }

    @MainActor
    private static func runMaintenance(on container: ModelContainer) throws {
        let context = ModelContext(container)
        try InventoryPlaceReconciler.reconcile(in: context)
        try InventoryLocationReconciler.reconcile(in: context)
        try InventoryRecentItemViews.repairPersistedEvents(in: context)
        try InventoryPlaceOpenPersistence.repairPersistedRecords(in: context)
    }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryMovementRecord.self,
            InventoryPlaceMutationRecord.self,
            InventoryItemViewEvent.self,
            InventoryPlaceOpenRecord.self,
            InventoryPlace.self,
            InventoryCustomCategory.self,
            StorageLocation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    #if DEBUG
    @MainActor
    static func makeSample(inMemory: Bool = true) throws -> ModelContainer {
        let container = try make(inMemory: inMemory)
        let context = ModelContext(container)
        try InventorySampleDataSeeder.seedIfNeeded(in: context)
        if InventoryLocationDetailEmptyFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryLocationDetailEmptyFixture.seed(in: context)
        }
        if InventoryRecentItemsLayoutFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryRecentItemsLayoutFixture.seed(
                in: context,
                count: InventoryRecentItemsLayoutFixture.itemCount(arguments: ProcessInfo.processInfo.arguments)
            )
        }
        if InventoryPlacePopularityFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryPlacePopularityFixture.seed(in: context)
        }
        if InventoryPlaceCategoryFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryPlaceCategoryFixture.seed(in: context)
        }
        if InventoryPlaceManagementFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryPlaceManagementFixture.seed(in: context)
        }
        if InventoryHierarchyManagementFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryHierarchyManagementFixture.seed(in: context)
        }
        try runMaintenance(on: container)
        if InventoryMovementHistoryFixture.isEnabled(arguments: ProcessInfo.processInfo.arguments) {
            try InventoryMovementHistoryFixture.seed(in: context)
        }
        return container
    }

    @MainActor
    static func makeAppStoreDemo(
        locale: InventoryAppStoreDemoLocale,
        inMemory: Bool = true,
        now: Date = .now
    ) throws -> ModelContainer {
        let container = try make(inMemory: inMemory)
        try InventoryAppStoreDemoDataSeeder.seed(in: ModelContext(container), locale: locale, now: now)
        try runMaintenance(on: container)
        return container
    }

    @MainActor
    static func makeManagedValueRowRegressionSample() throws -> ModelContainer {
        let container = try make(inMemory: true)
        let context = ModelContext(container)
        try ManagedValueRowRegressionData.seed(in: context)
        try runMaintenance(on: container)
        return container
    }
    #endif
}

#if DEBUG
enum AppStoreDemoDataConfiguration {
    static let launchArgument = "--use-app-store-demo-data"
    static let localeArgument = "--app-store-demo-locale"

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func requestedLocale(arguments: [String]) -> InventoryAppStoreDemoLocale? {
        guard let index = arguments.firstIndex(of: localeArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return InventoryAppStoreDemoLocale(rawValue: arguments[index + 1])
    }
}

enum AppStoreDemoDataConfigurationError: Error, Equatable {
    case invalidLocale
}

enum SampleDataConfiguration {
    static let launchArgument = "--use-sample-inventory-data"
    static let longPlaceFixtureLaunchArgument = "--use-long-place-fixture"
    static let environmentKey = "INVENTORY_USE_SAMPLE_DATA"

    static var isEnabled: Bool {
        isEnabled(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static var usesLongPlaceFixture: Bool {
        ProcessInfo.processInfo.arguments.contains(longPlaceFixtureLaunchArgument)
    }

    static func isEnabled(arguments: [String], environment: [String: String]) -> Bool {
        arguments.contains(launchArgument) || environment[environmentKey] == "1"
    }
}

enum ManagedValueRowRegressionConfiguration {
    static let launchArgument = "--use-managed-value-row-regression-data"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}

#endif
