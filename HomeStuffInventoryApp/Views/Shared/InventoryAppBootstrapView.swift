import Observation
import os
import SwiftData
import SwiftUI

enum InventoryAppBootstrapPhase {
    case loading
    case ready(ModelContainer)
    case unavailable
}

@Observable
@MainActor
final class InventoryAppBootstrapState {
    private(set) var phase: InventoryAppBootstrapPhase = .loading
    private var hasStarted = false
    private let loadContainer: () -> InventoryModelContainerStartupResult

    init(loadContainer: (() -> InventoryModelContainerStartupResult)? = nil) {
        if let loadContainer {
            self.loadContainer = loadContainer
        } else {
            let factory = InventoryAppBootstrapContainerFactory()
            self.loadContainer = factory.load
        }
    }

    func start() {
        guard !hasStarted, case .loading = phase else { return }
        hasStarted = true
        load()
    }

    func retry() {
        guard case .unavailable = phase else { return }
        load()
    }

    private func load() {
        phase = .loading

        switch loadContainer() {
        case let .success(container):
            phase = .ready(container)
        case .failure:
            InventoryAppBootstrapContainerFactory.logger.error("Bootstrap persistent-store startup failed")
            phase = .unavailable
        }
    }
}

@MainActor
private final class InventoryAppBootstrapContainerFactory {
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HomeStuffInventoryApp",
        category: "PersistentStoreStartup"
    )

    private var attempts = 0

    func load() -> InventoryModelContainerStartupResult {
        attempts += 1

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--qa-force-store-startup-failure")
            || (arguments.contains("--qa-force-store-startup-failure-once") && attempts == 1) {
            return .failure(InventoryModelContainerStartupError(underlyingError: QAForcedStartupFailure()))
        }
        #endif

        return InventoryModelContainer.loadLive()
    }
}

#if DEBUG
private struct QAForcedStartupFailure: LocalizedError {
    var errorDescription: String? { "QA-requested persistent store startup failure" }
}
#endif

struct InventoryAppBootstrapView: View {
    @Bindable var bootstrap: InventoryAppBootstrapState

    var body: some View {
        Group {
            switch bootstrap.phase {
            case .loading:
                ProgressView("inventory.startup.loading")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("inventory.startup.loading")
            case let .ready(container):
                RootView()
                    .modelContainer(container)
            case .unavailable:
                recoveryScreen
            }
        }
        .task {
            bootstrap.start()
        }
    }

    private var recoveryScreen: some View {
        InventoryEmptyStateScreen {
            InventoryEmptyStateCard(
                title: "inventory.startup.unavailable.title",
                message: "inventory.startup.unavailable.message",
                systemImage: "externaldrive.badge.exclamationmark"
            ) {
                Button("inventory.startup.tryAgain") {
                    bootstrap.retry()
                }
                .inventoryEmptyStatePrimaryAction()
                .accessibilityLabel("inventory.startup.tryAgain.accessibilityLabel")
                .accessibilityHint("inventory.startup.tryAgain.accessibilityHint")
                .accessibilityIdentifier("inventory.startup.tryAgain")
            }
            .accessibilityIdentifier("inventory.startup.recovery")
        }
    }
}
