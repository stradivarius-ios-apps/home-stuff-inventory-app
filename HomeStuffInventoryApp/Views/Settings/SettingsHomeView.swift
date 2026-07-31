import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum InventorySettingsAlert: Identifiable {
    case dataFileDisclosure(InventoryDataFileAction)
    case transferOutcome(InventoryDataTransferOutcome)
    case restoreSucceeded

    var id: String {
        switch self {
        case let .dataFileDisclosure(action):
            "disclosure.\(action.id)"
        case let .transferOutcome(outcome):
            "outcome.\(outcome.id)"
        case .restoreSucceeded:
            "restoreSucceeded"
        }
    }
}

struct SettingsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumUpgradeCoordinator.self) private var upgradeCoordinator
    @Query private var items: [InventoryItem]
    @Query private var locations: [StorageLocation]
    @Query private var customCategories: [InventoryCustomCategory]
    @Query private var places: [InventoryPlace]
    @Query private var movementRecords: [InventoryMovementRecord]

    @State private var workflow = InventoryDataTransferWorkflow()
    @State private var isShowingMovementHistory = false
#if DEBUG
    @State private var exportInvocationCompleted = false
    @State private var backupInvocationCompleted = false
    @State private var restoreInvocationCompleted = false
#endif

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.introduction.title")
                        .font(.headline)

                    Text("settings.introduction.body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    upgradeCoordinator.request(.settings)
                } label: {
                    HStack(spacing: 12) {
                        InventorySettingsNavigationRow(
                            "premium.title",
                            systemImage: "sparkles"
                        )
                        Spacer()
                        Text(
                            upgradeCoordinator.premiumAccess.entitlements.hasLocalProFeatures
                                ? "premium.settings.owned"
                                : "premium.settings.available"
                        )
                        .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("premium.settings.hint")
                .accessibilityIdentifier("settings.pro")

                Button("premium.restore") {
                    upgradeCoordinator.request(.settings)
                    Task { await upgradeCoordinator.restore() }
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.pro.restore")

                Button {
                    upgradeCoordinator.request(.extendedMovementUndo) {
                        isShowingMovementHistory = true
                    }
                } label: {
                    InventorySettingsNavigationRow(
                        "premium.history.title",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.pro.history")
            } header: {
                Text("premium.settings.section")
            }
            .inventoryFormRowSurface()

            Section {
                NavigationLink {
                    InventoryListManagementView(scope: .locations)
                } label: {
                    InventorySettingsNavigationRow(
                        "settings.lists.locations",
                        systemImage: "map",
                        iconRole: .storage
                    )
                }
                .accessibilityLabel("settings.lists.locations.accessibilityLabel")
                .accessibilityIdentifier("settings.lists.locationsLink")

                NavigationLink {
                    PlaceManagementView()
                } label: {
                    InventorySettingsNavigationRow("settings.lists.places", systemImage: "shippingbox", iconRole: .place)
                }
                .accessibilityLabel("settings.lists.places.accessibilityLabel")
                .accessibilityIdentifier("settings.lists.placesLink")

                NavigationLink {
                    InventoryListManagementView(scope: .categories)
                } label: {
                    InventorySettingsNavigationRow("settings.lists.categories", systemImage: "tag")
                }
                .accessibilityLabel("settings.lists.categories.accessibilityLabel")
                .accessibilityIdentifier("settings.lists.categoriesLink")
            } header: {
                Text("settings.section.lists")
            }
            .inventoryFormRowSurface()

            Section {
                Button(action: { workflow.requestDisclosure(for: .readableExport) }) {
                    InventorySettingsNavigationRow(
                        "settings.export.title",
                        systemImage: "square.and.arrow.up",
                        iconRole: .storage
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!workflow.canRequestDataTransfer)
                .accessibilityLabel("settings.export.accessibilityLabel")
                .accessibilityHint("settings.export.accessibilityHint")
                .accessibilityIdentifier("settings.export.action")

                Button {
                    workflow.requestDisclosure(for: .completeBackup)
                } label: {
                    HStack(spacing: 12) {
                        InventorySettingsNavigationRow(
                            "settings.backup.title",
                            systemImage: "externaldrive.badge.plus"
                        )

                        if workflow.isPreparingBackup {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!workflow.canRequestDataTransfer)
                .accessibilityLabel("settings.backup.accessibilityLabel")
                .accessibilityHint("settings.backup.accessibilityHint")
                .accessibilityIdentifier("settings.backup.action")

                Button {
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--qa-suppress-restore-importer") {
                        restoreInvocationCompleted = true
                        return
                    }
#endif
                    workflow.requestRestoreImport()
                } label: {
                    HStack(spacing: 12) {
                        InventorySettingsNavigationRow(
                            "settings.restore.title",
                            systemImage: "arrow.down.doc"
                        )

                        if workflow.isPlanningRestore {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!workflow.canRequestDataTransfer)
                .accessibilityLabel("settings.restore.accessibilityLabel")
                .accessibilityHint("settings.restore.accessibilityHint")
                .accessibilityIdentifier("settings.restore.action")
            } header: {
                Text("settings.section.data")
            }
            .inventoryFormRowSurface()
        }
        .listStyle(.insetGrouped)
        .inventoryFormPresentation()
        .navigationTitle("settings.title")
        .alert(item: presentedAlert) { settingsAlert(for: $0) }
        .sheet(item: $workflow.exportArtifact, onDismiss: workflow.cleanupExportArtifact) { artifact in
            InventoryActivityShareView(url: artifact.url) { result in
                workflow.completeShare(result)
            }
        }
        .sheet(isPresented: $isShowingMovementHistory) {
            InventoryMovementHistoryView()
        }
        .fileExporter(
            isPresented: $workflow.isBackupExporterPresented,
            document: workflow.backupDocument,
            contentType: .json,
            defaultFilename: workflow.backupFilename
        ) { result in
            workflow.completeBackupExport(result)
        }
        .fileImporter(
            isPresented: $workflow.isRestoreImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            workflow.handleRestoreSelection(result)
        }
        .sheet(item: $workflow.restorePlan, onDismiss: workflow.cancelRestoreConfirmation) { plan in
            InventoryBackupRestorePreflightView(plan: plan) { result in
                workflow.completeRestore(result)
            }
        }
#if DEBUG
        .overlay {
            if exportInvocationCompleted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("settings.export.invocationCompleted")
                    .allowsHitTesting(false)
            }
            if backupInvocationCompleted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("settings.backup.invocationCompleted")
                    .allowsHitTesting(false)
            }
            if restoreInvocationCompleted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("settings.restore.invocationCompleted")
                    .allowsHitTesting(false)
            }
        }
#endif
        .onDisappear {
            workflow.cancelOutstandingWork()
        }
#if DEBUG
        .onChange(of: workflow.isBackupExporterPresented) { _, isPresented in
            guard isPresented,
                  ProcessInfo.processInfo.arguments.contains("--qa-suppress-backup-file-exporter")
            else { return }
            workflow.discardPreparedBackup()
            backupInvocationCompleted = true
        }
#endif
    }

    private var activeAlert: InventorySettingsAlert? {
        if let action = workflow.pendingDisclosureAction {
            return .dataFileDisclosure(action)
        }
        if let outcome = workflow.transferOutcome {
            return .transferOutcome(outcome)
        }
        return workflow.restoreSucceeded ? .restoreSucceeded : nil
    }

    private var presentedAlert: Binding<InventorySettingsAlert?> {
        Binding(
            get: { activeAlert },
            set: { newValue in
                guard newValue == nil, let currentAlert = activeAlert else { return }
                dismiss(currentAlert)
            }
        )
    }

    private func settingsAlert(for alert: InventorySettingsAlert) -> Alert {
        switch alert {
        case let .dataFileDisclosure(action):
            Alert(
                title: Text("settings.fileDisclosure.title"),
                message: Text(action.messageKey),
                primaryButton: .default(Text(action.continueKey)) {
                    confirmDataFileAction(action)
                },
                secondaryButton: .cancel(Text("settings.fileDisclosure.cancel")) {
                    workflow.cancelDisclosure()
                }
            )
        case let .transferOutcome(outcome):
            transferOutcomeAlert(outcome)
        case .restoreSucceeded:
            Alert(
                title: Text("settings.restore.success.title"),
                message: Text("settings.restore.success.message"),
                dismissButton: .default(Text("settings.restore.success.dismiss"))
            )
        }
    }

    private func transferOutcomeAlert(_ outcome: InventoryDataTransferOutcome) -> Alert {
        switch outcome {
        case .readableExport:
            Alert(
                title: Text(outcome.titleKey),
                message: Text(outcome.messageKey),
                primaryButton: .default(Text("settings.export.failure.retry")) {
                    workflow.export(
                        items: items,
                        locations: locations,
                        customCategories: customCategories,
                        places: places,
                        movementRecords: movementRecords
                    )
                },
                secondaryButton: .cancel()
            )
        case .backup:
            Alert(
                title: Text(outcome.titleKey),
                message: Text(outcome.messageKey),
                dismissButton: .default(Text("settings.backup.error.dismiss"))
            )
        case .restore:
            Alert(
                title: Text(outcome.titleKey),
                message: Text(outcome.messageKey),
                dismissButton: .default(Text("settings.restore.error.dismiss"))
            )
        }
    }

    private func dismiss(_ alert: InventorySettingsAlert) {
        switch alert {
        case .dataFileDisclosure:
            break
        case let .transferOutcome(outcome):
            switch outcome {
            case .readableExport:
                workflow.dismissOutcome()
            case .backup:
                workflow.dismissOutcome()
            case .restore:
                workflow.dismissOutcome()
            }
        case .restoreSucceeded:
            workflow.dismissRestoreSuccess()
        }
    }

    private func confirmDataFileAction(_ action: InventoryDataFileAction) {
        workflow.confirmDisclosure(
            action,
            items: items,
            locations: locations,
            customCategories: customCategories,
            places: places,
            movementRecords: movementRecords,
            context: modelContext
        )
#if DEBUG
        guard action == .readableExport,
              ProcessInfo.processInfo.arguments.contains("--qa-suppress-export-share-sheet"),
              workflow.exportArtifact != nil
        else { return }
        workflow.cleanupExportArtifact()
        exportInvocationCompleted = true
#endif
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsHomeView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
}
#endif
