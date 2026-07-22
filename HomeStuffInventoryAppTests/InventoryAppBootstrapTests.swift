import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryAppBootstrapTests {
    @Test func liveFactoryReturnsContainerAfterPersistentCreationAndMaintenance() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        var maintenanceRuns = 0

        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: { container },
            recoverPendingRestore: { _ in },
            runMaintenance: { _ in maintenanceRuns += 1 }
        )

        if case let .success(returnedContainer) = result {
            #expect(returnedContainer === container)
        } else {
            Issue.record("Expected a successful startup result")
        }
        #expect(maintenanceRuns == 1)
    }

    @Test func liveFactoryReturnsFailureWithoutMaintenanceOrInMemoryFallback() {
        var maintenanceRuns = 0
        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: { throw StartupTestError.failed },
            recoverPendingRestore: { _ in },
            runMaintenance: { _ in maintenanceRuns += 1 }
        )

        if case let .failure(error) = result {
            #expect((error.underlyingError as? StartupTestError) == .failed)
        } else {
            Issue.record("Expected a failed startup result")
        }
        #expect(maintenanceRuns == 0)
    }

    @Test func maintenanceFailureKeepsSuccessfullyOpenedStoreAvailable() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: { container },
            recoverPendingRestore: { _ in },
            runMaintenance: { _ in throw StartupTestError.failed }
        )

        if case let .success(returnedContainer) = result {
            #expect(returnedContainer === container)
        } else {
            Issue.record("Maintenance must not hide a successfully opened store")
        }
    }

    @Test func startupMaintenanceRepairsOrphanAndExpiredRecentViewEvents() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date.now
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        let valid = InventoryItemViewEvent(itemID: item.id, viewedAt: now)
        let orphan = InventoryItemViewEvent(itemID: UUID(), viewedAt: now)
        let expired = InventoryItemViewEvent(
            itemID: item.id,
            viewedAt: now.addingTimeInterval(-InventoryRecentItemViews.defaultRollingWindow - 1)
        )
        context.insert(item)
        [valid, orphan, expired].forEach(context.insert)
        try context.save()

        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: { container },
            recoverPendingRestore: { _ in }
        )

        if case .failure = result {
            Issue.record("Expected maintenance to preserve the available store")
        }
        #expect(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id) == [valid.id])
    }

    @Test func pendingRestoreRecoveryRunsBeforeMaintenanceAndCanBlockStartup() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        var events: [String] = []

        let success = InventoryModelContainer.loadLive(
            makePersistentContainer: { container },
            recoverPendingRestore: { _ in events.append("recovery") },
            runMaintenance: { _ in events.append("maintenance") }
        )
        if case .success = success {} else {
            Issue.record("Expected successful startup")
        }
        #expect(events == ["recovery", "maintenance"])

        events = []
        let failure = InventoryModelContainer.loadLive(
            makePersistentContainer: { container },
            recoverPendingRestore: { _ in throw StartupTestError.failed },
            runMaintenance: { _ in events.append("maintenance") }
        )
        if case let .failure(error) = failure {
            #expect((error.underlyingError as? StartupTestError) == .failed)
        } else {
            Issue.record("Recovery failure must keep startup unavailable")
        }
        #expect(events.isEmpty)
    }

    @Test func sampleDataModeRemainsEnabledOnlyForItsExistingFlags() {
        #if DEBUG
        #expect(SampleDataConfiguration.isEnabled(arguments: [SampleDataConfiguration.launchArgument], environment: [:]))
        #expect(SampleDataConfiguration.isEnabled(arguments: [], environment: [SampleDataConfiguration.environmentKey: "1"]))
        #expect(!SampleDataConfiguration.isEnabled(arguments: [], environment: [:]))
        #endif
    }

    @Test func bootstrapTransitionsFromSuccessToNormalRootState() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let state = InventoryAppBootstrapState(loadContainer: { .success(container) })

        state.start()

        if case let .ready(returnedContainer) = state.phase {
            #expect(returnedContainer === container)
        } else {
            Issue.record("Expected the normal-root state")
        }
    }

    @Test func bootstrapStaysRecoverableAfterFailureAndCanRetryToSuccess() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        var attempts = 0
        let state = InventoryAppBootstrapState(loadContainer: {
            attempts += 1
            return attempts == 1
                ? .failure(InventoryModelContainerStartupError(underlyingError: StartupTestError.failed))
                : .success(container)
        })

        state.start()
        guard case .unavailable = state.phase else {
            Issue.record("Expected recovery state after the first failed attempt")
            return
        }

        state.retry()
        if case let .ready(returnedContainer) = state.phase {
            #expect(returnedContainer === container)
        } else {
            Issue.record("Expected normal-root state after retry")
        }
        #expect(attempts == 2)
    }

    @Test func duplicateStartAndRetryCallsAreIgnoredOutsideRecovery() {
        var attempts = 0
        let state = InventoryAppBootstrapState(loadContainer: {
            attempts += 1
            return .failure(InventoryModelContainerStartupError(underlyingError: StartupTestError.failed))
        })

        state.start()
        state.start()
        state.retry()
        state.retry()

        #expect(attempts == 3)
    }
}

private enum StartupTestError: Error, Equatable {
    case failed
}
