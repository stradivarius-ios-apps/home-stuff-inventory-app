import Foundation
import os
import Testing
@testable import HomeStuffInventoryApp

struct InventoryReadableExportServiceTests {
    private let timestamp = Date(timeIntervalSince1970: 1_752_489_000)

    @Test func emptyInventoryProducesTruthfulVerifiedReadableDocument() throws {
        let artifact = try service().export(
            items: [],
            locations: [],
            customCategories: [],
            createdAt: timestamp,
            artifactID: UUID(uuidString: "90000000-0000-0000-0000-000000000001")!
        )
        defer { artifact.cleanup() }

        let data = try Data(contentsOf: artifact.url)
        let document = try InventoryPortabilityEncoder.decodeAndVerify(data)
        #expect(document.artifactType == .readableExport)
        #expect(document.inventory.items.isEmpty)
        #expect(document.inventory.locations.isEmpty)
        #expect(document.inventory.customCategories.isEmpty)
        #expect(document.inventory.recentItemViewEvents == nil)
        #expect(data.last == 0x0A)
    }

    @Test func fullExportPreservesUnicodeEveryFieldAndOptionalValues() throws {
        let fixture = fullFixture()
        let artifact = try service().export(
            items: fixture.items,
            locations: fixture.locations,
            customCategories: fixture.categories,
            createdAt: timestamp
        )
        defer { artifact.cleanup() }

        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))
        let item = try #require(document.inventory.items.first {
            $0.id == "30000000-0000-0000-0000-000000000002"
        })
        #expect(item.name == "Кабель USB-C — запасний")
        #expect(item.categoryStorageValue == "Пам’ятні речі")
        #expect(item.customCategoryID == "20000000-0000-0000-0000-000000000002")
        #expect(item.locationName == "Кімната 🏠")
        #expect(item.locationID == "10000000-0000-0000-0000-000000000002")
        #expect(item.placeName == "Шухляда №2")
        #expect(item.quantity == 3)
        #expect(item.conditionStorageValue == InventoryCondition.good.rawValue)
        #expect(item.tags == ["USB-C", "запас"])
        #expect(item.notes == "Для подорожей. Не загубити!")
        #expect(item.createdAt == "2025-07-14T10:30:00.000Z")
        #expect(item.updatedAt == "2025-07-14T10:30:00.000Z")
    }

    @Test func outputIsDeterministicAndSortedByLowercaseUUID() throws {
        let fixture = fullFixture()
        let first = try service().export(
            items: fixture.items.reversed(),
            locations: fixture.locations.reversed(),
            customCategories: fixture.categories.reversed(),
            createdAt: timestamp
        )
        let second = try service().export(
            items: fixture.items,
            locations: fixture.locations,
            customCategories: fixture.categories,
            createdAt: timestamp
        )
        defer {
            first.cleanup()
            second.cleanup()
        }

        #expect(try Data(contentsOf: first.url) == Data(contentsOf: second.url))
        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: first.url))
        #expect(document.inventory.items.map(\.id) == document.inventory.items.map(\.id).sorted())
    }

    @Test func trimsEmptyReadablePlaceWithoutChangingSourceItem() throws {
        let item = InventoryItem(name: "Adapter", locationName: "", containerName: "  ", notes: "")
        let originalUpdatedAt = item.updatedAt
        let artifact = try service().export(
            items: [item],
            locations: [],
            customCategories: [],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }

        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))
        #expect(document.inventory.items.first?.placeName == nil)
        #expect(item.containerName == "  ")
        #expect(item.updatedAt == originalUpdatedAt)
    }

    @Test func injectedWriteFailuresAreTypedAndRemovePartialDirectory() throws {
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.write = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let service = InventoryReadableExportService(fileSystem: fileSystem)

        #expect(throws: InventoryReadableExportError.destinationWriteFailed) {
            try service.export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }

        fileSystem.write = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        #expect(throws: InventoryReadableExportError.lowStorage) {
            try InventoryReadableExportService(fileSystem: fileSystem)
                .export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }
    }

    @Test func generationLimitFailureCreatesNoExportArtifact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { directory }
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 1, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10,
            maximumRecentItemViewEvents: 10, maximumTagsPerItem: 10,
            maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        #expect(throws: InventoryReadableExportError.unsupportedPortabilityLimits) {
            try InventoryReadableExportService(fileSystem: fileSystem, bundle: Bundle(for: TestBundleMarker.self), limits: limits)
                .export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func exportHasNoEntitlementOrNetworkDependency() throws {
        for state in InventoryEntitlementState.allCases {
            #expect(
                InventoryFreeAccessPolicy().availability(of: .exportInventory, entitlementState: state) == .available
            )
        }
        let artifact = try service().export(
            items: [InventoryItem(name: "Offline item", locationName: "Home")],
            locations: [],
            customCategories: [],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }
        #expect(FileManager.default.fileExists(atPath: artifact.url.path))
    }

    @Test func readableExportPreservesTheCompleteNestedPlacePathWithoutEntitlement() throws {
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Workshop",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let root = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
            locationID: location.id,
            name: "Cabinet",
            iconID: "cabinet",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let child = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
            locationID: location.id,
            parentPlaceID: root.id,
            name: "Drawer",
            iconID: "drawer",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let leaf = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
            locationID: location.id,
            parentPlaceID: child.id,
            name: "Cable box",
            iconID: "box",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let item = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Adapter",
            locationName: location.name,
            containerName: leaf.name,
            placeID: leaf.id,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let artifact = try service().export(
            items: [item],
            locations: [location],
            customCategories: [],
            places: [leaf, root, child],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }
        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))

        #expect(document.schemaVersion == 4)
        #expect(document.inventory.places.map(\.id) == [leaf.id, child.id, root.id].map(\.inventoryPortabilityString))
        #expect(document.inventory.places.map(\.parentPlaceID) == [
            child.id.inventoryPortabilityString,
            root.id.inventoryPortabilityString,
            nil
        ])
        #expect(document.inventory.items.first?.placeID == leaf.id.inventoryPortabilityString)
    }

    private func service() -> InventoryReadableExportService {
        InventoryReadableExportService(bundle: Bundle(for: TestBundleMarker.self))
    }

    private func fullFixture() -> (
        items: [InventoryItem],
        locations: [StorageLocation],
        categories: [InventoryCustomCategory]
    ) {
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Кімната 🏠",
            notes: "Основне місце",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let category = InventoryCustomCategory(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            name: "Пам’ятні речі",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let item = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            name: "Кабель USB-C — запасний",
            category: category.name,
            locationName: location.name,
            containerName: "Шухляда №2",
            quantity: 3,
            condition: InventoryCondition.good.rawValue,
            tags: ["USB-C", "запас"],
            notes: "Для подорожей. Не загубити!",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let earlierItem = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Empty optionals",
            locationName: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return ([item, earlierItem], [location], [category])
    }
}

private final class TestBundleMarker {}

@MainActor
struct InventoryReadableExportConcurrencyTests {
    private func snapshot() -> InventoryPortabilitySnapshotV1 {
        InventoryReadableExportService().makeSnapshot(items: [], locations: [], customCategories: [])
    }

    @Test func workerProducesIdenticalBytesAndKeepsFileOperationsOffMainActor() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let removed = AsyncStream<Void>.makeStream()
        let cleanupCount = OSAllocatedUnfairLock(initialState: 0)
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { root }
        fileSystem.createDirectory = { url in
            #expect(!Thread.isMainThread)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        fileSystem.write = { data, url in
            #expect(!Thread.isMainThread)
            try data.write(to: url, options: .atomic)
        }
        fileSystem.read = { url in
            #expect(!Thread.isMainThread)
            return try Data(contentsOf: url)
        }
        fileSystem.remove = { url in
            #expect(!Thread.isMainThread)
            cleanupCount.withLock { $0 += 1 }
            try? FileManager.default.removeItem(at: url)
            removed.continuation.yield()
        }
        let worker = InventoryReadableExportWorker(service: InventoryReadableExportService(fileSystem: fileSystem))
        let timestamp = Date(timeIntervalSince1970: 1_752_489_000)
        let item = InventoryItem(name: "Кабель — spare", locationName: "", containerName: " ",
                                 tags: ["spare"], notes: "Unicode 📦", createdAt: timestamp, updatedAt: timestamp)
        let captured = InventoryReadableExportService().makeSnapshot(items: [item], locations: [], customCategories: [])
        let prepared = try await worker.prepare(snapshot: captured, createdAt: timestamp)
        let expected = try InventoryPortabilityEncoder.encode(
            snapshot: captured,
            metadata: InventoryPortabilityMetadataV1(createdAt: timestamp,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"),
            artifactType: .readableExport, prettyPrinted: true
        )
        #expect(try Data(contentsOf: prepared.url) == expected)
        await worker.cleanup(prepared)
        #expect(!FileManager.default.fileExists(atPath: prepared.url.path))
        let artifact = try await worker.export(snapshot: snapshot())
        artifact.cleanup()
        artifact.cleanup()
        var iterator = removed.stream.makeAsyncIterator()
        _ = await iterator.next() // The explicit prepared-file cleanup.
        _ = await iterator.next() // The queued live-artifact cleanup.
        #expect(cleanupCount.withLock { $0 } == 2)
        #expect(!FileManager.default.fileExists(atPath: artifact.url.path))
        removed.continuation.finish()
    }

    @Test func cancellationDuringWriteCleansOutputWhileMainActorRemainsAvailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let entered = AsyncStream<Void>.makeStream()
        let release = DispatchSemaphore(value: 0)
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { root }
        fileSystem.write = { data, url in
            #expect(!Thread.isMainThread)
            try data.write(to: url, options: .atomic)
            entered.continuation.yield()
            #expect(release.wait(timeout: .now() + 5) == .success)
        }
        let worker = InventoryReadableExportWorker(service: InventoryReadableExportService(fileSystem: fileSystem))
        let task = Task {
            let artifact = try await worker.export(snapshot: snapshot())
            artifact.cleanup()
        }
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        MainActor.assertIsolated()
        task.cancel()
        release.signal()
        await #expect(throws: CancellationError.self) { try await task.value }
        let ownedRoot = root.appendingPathComponent("HomeStuffInventoryExports")
        #expect(try FileManager.default.contentsOfDirectory(atPath: ownedRoot.path).isEmpty)
        entered.continuation.finish()
    }

    @Test(arguments: [0, 1, 2, 3])
    func workerFailuresRemovePartialOutput(mode: Int) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { root }
        if mode < 2 {
            fileSystem.write = { data, url in
                try data.write(to: url)
                throw CocoaError(mode == 0 ? .fileWriteOutOfSpace : .fileWriteUnknown)
            }
        } else if mode == 2 {
            fileSystem.read = { _ in throw CocoaError(.fileReadUnknown) }
        } else {
            fileSystem.read = { _ in Data("{}".utf8) }
        }
        let worker = InventoryReadableExportWorker(service: InventoryReadableExportService(fileSystem: fileSystem))
        do {
            _ = try await worker.prepare(snapshot: snapshot())
            Issue.record("Expected a typed file-preparation failure")
        } catch {
            #expect(error as? InventoryReadableExportError == (mode == 0 ? .lowStorage : .destinationWriteFailed))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("HomeStuffInventoryExports").path).isEmpty)
    }

    @Test func cancellationBeforePreparationCreatesNoDirectory() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { root }
        let worker = InventoryReadableExportWorker(service: InventoryReadableExportService(fileSystem: fileSystem))
        let task = Task { try await worker.prepare(snapshot: snapshot()) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func staleResultCannotReplaceNewShareAndOwnerLifetimeCleansLateFile() async {
        let firstGate = ReadableExportTestGate()
        var cleanupCount = 0
        let stale = InventoryReadableExportArtifact(id: UUID(), url: URL(fileURLWithPath: "/tmp/stale-export"), cleanupAction: {})
        let current = InventoryReadableExportArtifact(id: UUID(), url: URL(fileURLWithPath: "/tmp/current-export"), cleanupAction: {})
        var calls = 0
        var workflow: InventoryDataTransferWorkflow? = InventoryDataTransferWorkflow(
            readableExport: { _ in
                calls += 1
                return calls == 1 ? try await firstGate.wait() : current
            }, artifactCleanup: { _ in cleanupCount += 1 }
        )
        workflow?.export(items: [], locations: [], customCategories: [])
        await waitUntil { firstGate.hasStarted }
        workflow?.cancelOutstandingWork()
        workflow?.export(items: [], locations: [], customCategories: [])
        await waitUntil { workflow?.phase == .sharingReadableExport }
        firstGate.finish(stale)
        await waitUntil { cleanupCount == 1 }
        #expect(workflow?.exportArtifact === current)
        #expect(workflow?.phase == .sharingReadableExport)
        workflow?.cancelOutstandingWork()
        #expect(cleanupCount == 2)

        let ownerGate = ReadableExportTestGate()
        workflow = InventoryDataTransferWorkflow(readableExport: { _ in try await ownerGate.wait() },
                                                 artifactCleanup: { _ in cleanupCount += 1 })
        weak var owner = workflow
        workflow?.export(items: [], locations: [], customCategories: [])
        await waitUntil { ownerGate.hasStarted }
        workflow = nil
        #expect(owner == nil)
        ownerGate.finish(stale)
        await waitUntil { cleanupCount == 3 }
        workflow = InventoryDataTransferWorkflow(readableExport: { _ in current },
                                                 artifactCleanup: { _ in cleanupCount += 1 })
        workflow?.export(items: [], locations: [], customCategories: [])
        await waitUntil { workflow?.phase == .sharingReadableExport }
        workflow = nil
        #expect(cleanupCount == 4)
    }

    @Test func dependencyCancellationReturnsToIdleWithoutAnOutcome() async {
        let workflow = InventoryDataTransferWorkflow(readableExport: { _ in throw CancellationError() })
        workflow.export(items: [], locations: [], customCategories: [])
        await waitUntil { workflow.phase == .idle }
        #expect(workflow.transferOutcome == nil)
        #expect(workflow.exportArtifact == nil)
    }

    @Test func snapshotDateFormattingRemainsEquivalentAndCapturePrecedesSuspension() async {
        let createdAt = Date(timeIntervalSince1970: -123.456)
        let updatedAt = Date(timeIntervalSince1970: 1_752_489_000.789)
        let item = InventoryItem(name: "Original", locationName: "", createdAt: createdAt, updatedAt: updatedAt)
        let gate = ReadableExportTestGate()
        var captured: InventoryPortabilitySnapshotV1?
        var didCleanup = false
        let workflow = InventoryDataTransferWorkflow(readableExport: { snapshot in
            captured = snapshot
            return try await gate.wait()
        }, artifactCleanup: { artifact in artifact.cleanup(); didCleanup = true })
        workflow.export(items: [item], locations: [], customCategories: [])
        item.name = "Changed after request"
        await waitUntil { gate.hasStarted }
        #expect(captured?.items.first?.name == "Original")
        #expect(captured?.items.first?.createdAt == InventoryPortabilityDate.string(from: createdAt))
        #expect(captured?.items.first?.updatedAt == InventoryPortabilityDate.string(from: updatedAt))
        workflow.cancelOutstandingWork()
        gate.finish(InventoryReadableExportArtifact(id: UUID(), url: URL(fileURLWithPath: "/tmp/captured-export"), cleanupAction: {}))
        await waitUntil { didCleanup }
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
        #expect(condition())
    }
}

@MainActor
private final class ReadableExportTestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var artifact: InventoryReadableExportArtifact?
    private(set) var hasStarted = false

    func wait() async throws -> InventoryReadableExportArtifact {
        hasStarted = true
        await withCheckedContinuation { continuation = $0 }
        let result = artifact!
        artifact = nil
        return result
    }

    func finish(_ artifact: InventoryReadableExportArtifact) {
        self.artifact = artifact
        continuation?.resume()
        continuation = nil
    }
}
