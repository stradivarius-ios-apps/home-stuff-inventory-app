import SwiftData
import SwiftUI

struct InventoryMovementHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Environment(PremiumUpgradeCoordinator.self) private var upgradeCoordinator

    @Query(sort: \InventoryMovementRecord.occurredAt, order: .reverse)
    private var records: [InventoryMovementRecord]
    @Query private var items: [InventoryItem]
    @Query private var locations: [StorageLocation]
    @Query private var places: [InventoryPlace]

    @State private var outcomeKey: String?
    @State private var isShowingUndoConfirmation = false

    let itemID: UUID?

    init(itemID: UUID? = nil) {
        self.itemID = itemID
    }

    var body: some View {
        NavigationStack {
            List {
                if visibleRecords.isEmpty {
                    ContentUnavailableView(
                        "premium.history.empty.title",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("premium.history.empty.message")
                    )
                } else {
                    Section {
                        ForEach(visibleRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(itemName(for: record))
                                    .font(.headline)
                                Text("\(record.source.displayName) → \(record.destination.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(record.occurredAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text("premium.history.section")
                    }

                    if itemID == nil {
                        Section {
                            Button {
                                requestUndo()
                            } label: {
                                Text(
                                    InventoryLocalization.formatted(
                                        "premium.history.undo.count",
                                        defaultValue: "Undo Latest Move (%d Items)",
                                        latestOperationAffectedCount
                                    )
                                )
                            }
                            .frame(minHeight: 44)
                            .disabled(!isUndoEnabled)
                            .accessibilityIdentifier("premium.history.undo")
                        } footer: {
                            Text("premium.history.undo.footer")
                        }
                    }
                }
            }
            .navigationTitle("premium.history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("premium.dismiss") { dismiss() }
                }
            }
            .alert(
                "premium.history.outcome.title",
                isPresented: Binding(
                    get: { outcomeKey != nil },
                    set: { if !$0 { outcomeKey = nil } }
                )
            ) {
                Button("inventory.action.ok", role: .cancel) {}
            } message: {
                if let outcomeKey {
                    Text(LocalizedStringKey(outcomeKey))
                }
            }
            .confirmationDialog(
                "premium.history.undo.confirm.title",
                isPresented: $isShowingUndoConfirmation,
                titleVisibility: .visible
            ) {
                Button("premium.history.undo.confirm.action") {
                    undoLatest()
                }
                Button("inventory.action.cancel", role: .cancel) {}
            } message: {
                Text(
                    InventoryLocalization.formatted(
                        "premium.history.undo.confirm.message",
                        defaultValue: "Move %d affected Items back to their previous Storage Places?",
                        latestOperationAffectedCount
                    )
                )
            }
        }
    }

    private var visibleRecords: [InventoryMovementRecord] {
        InventoryMovementHistoryPresentation.records(records, for: itemID)
    }

    private var latestOperationAffectedCount: Int {
        InventoryMovementHistoryPresentation.latestAffectedItemCount(in: records)
    }

    private var undoAction: InventoryMovementHistoryPresentation.UndoAction {
        InventoryMovementHistoryPresentation.undoAction(
            itemID: itemID,
            records: records,
            items: items,
            locations: locations,
            places: places,
            entitlements: premiumAccess.entitlements
        )
    }

    private var isUndoEnabled: Bool {
        undoAction == .confirm || undoAction == .upgrade
    }

    private func itemName(for record: InventoryMovementRecord) -> String {
        items.first(where: { $0.id == record.itemID })?.name
            ?? InventoryLocalization.string(
                "premium.history.unknownItem",
                defaultValue: "Removed Item"
            )
    }

    private func requestUndo() {
        switch undoAction {
        case .hidden:
            break
        case .confirm:
            isShowingUndoConfirmation = true
        case .upgrade:
            upgradeCoordinator.request(.extendedMovementUndo) {
                requestUndo()
            }
        case .unavailable:
            outcomeKey = "premium.history.outcome.unavailable"
        case .currentStateChanged:
            outcomeKey = "premium.history.outcome.changed"
        case .unsafeRestoration:
            outcomeKey = "premium.history.outcome.unsafe"
        }
    }

    private func undoLatest() {
        let outcome = InventoryMovementHistory.undoLatest(
            records: records,
            items: items,
            locations: locations,
            places: places,
            entitlements: premiumAccess.entitlements,
            in: modelContext
        )
        switch outcome {
        case .undone:
            outcomeKey = "premium.history.outcome.undone"
        case .currentStateChanged:
            outcomeKey = "premium.history.outcome.changed"
        case .unsafeRestoration:
            outcomeKey = "premium.history.outcome.unsafe"
        case .accessRequired:
            upgradeCoordinator.request(.extendedMovementUndo) {
                undoLatest()
            }
        case .unavailable:
            outcomeKey = "premium.history.outcome.unavailable"
        case .failed:
            outcomeKey = "premium.history.outcome.failed"
        }
    }
}

enum InventoryMovementHistoryPresentation {
    enum UndoAction: Equatable {
        case hidden
        case confirm
        case upgrade
        case unavailable
        case currentStateChanged
        case unsafeRestoration
    }

    static func records(
        _ records: [InventoryMovementRecord],
        for itemID: UUID?
    ) -> [InventoryMovementRecord] {
        guard let itemID else { return records }
        return records.filter { $0.itemID == itemID }
    }

    static func latestAffectedItemCount(
        in records: [InventoryMovementRecord]
    ) -> Int {
        guard let operationID = records.first?.operationID else {
            return 0
        }
        return Set(records.filter { $0.operationID == operationID }.map(\.itemID)).count
    }

    static func undoAction(
        itemID: UUID?,
        records: [InventoryMovementRecord],
        items: [InventoryItem],
        locations: [StorageLocation],
        places: [InventoryPlace],
        entitlements: InventoryEntitlements
    ) -> UndoAction {
        guard itemID == nil else { return .hidden }
        return switch InventoryMovementHistory.undoAvailability(
            records: records,
            items: items,
            locations: locations,
            places: places,
            entitlements: entitlements
        ) {
        case .available: .confirm
        case .accessRequired: .upgrade
        case .unavailable: .unavailable
        case .currentStateChanged: .currentStateChanged
        case .unsafeRestoration: .unsafeRestoration
        }
    }
}

private extension InventoryMovementEndpointSnapshot {
    var displayName: String {
        if let placeName, !placeName.isEmpty {
            return "\(locationName) · \(placeName)"
        }
        return locationName
    }
}
