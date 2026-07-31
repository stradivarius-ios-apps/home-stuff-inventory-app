import SwiftData
import SwiftUI

struct InventoryBulkMovementSheetRequest: Identifiable {
    let id = UUID()
    let selectedItemIDs: Set<UUID>
}

struct InventoryBulkSelectionList: View {
    let items: [InventoryItem]
    @Binding var selectedItemIDs: Set<UUID>

    var body: some View {
        List(selection: $selectedItemIDs) {
            ForEach(items) { item in
                InventoryItemRowView(item: item, showsChevron: false)
                    .tag(item.id)
                    .accessibilityIdentifier("inventory.bulkSelection.item.\(item.id.uuidString)")
            }
        }
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("inventory.bulkSelection.list")
    }
}

struct InventoryBulkMovementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    let selectedItemIDs: Set<UUID>
    let onAccessRequired: () -> Void

    @State private var selectedDestinationID: InventoryBulkMovementDestination.Identity?
    @State private var preflight: InventoryBulkMovementPreflight?
    @State private var outcomeMessage: String?

    init(
        selectedItemIDs: Set<UUID>,
        onAccessRequired: @escaping () -> Void = {}
    ) {
        self.selectedItemIDs = selectedItemIDs
        self.onAccessRequired = onAccessRequired
    }

    private var destinations: [InventoryBulkMovementDestination] {
        InventoryBulkMovementDestinationDirectory.destinations(
            locations: locations,
            places: places
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let preflight {
                    preflightSections(preflight)
                } else {
                    destinationSections
                }
            }
            .navigationTitle(
                preflight == nil
                    ? InventoryLocalization.string(
                        "inventory.bulkMove.destination.title",
                        defaultValue: "Choose Destination"
                    )
                    : InventoryLocalization.string(
                        "inventory.bulkMove.review.title",
                        defaultValue: "Review Move"
                    )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.bulkMove.cancel") {
                        dismiss()
                    }
                }

                if preflight != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("inventory.bulkMove.back") {
                            preflight = nil
                        }
                    }
                }
            }
            .alert(
                InventoryLocalization.string(
                    "inventory.bulkMove.result.title",
                    defaultValue: "Couldn’t Move Items"
                ),
                isPresented: Binding(
                    get: { outcomeMessage != nil },
                    set: { if !$0 { outcomeMessage = nil } }
                )
            ) {
                Button("inventory.bulkMove.result.ok", role: .cancel) {}
            } message: {
                Text(outcomeMessage ?? "")
            }
        }
    }

    private var destinationSections: some View {
        Group {
            Section {
                LabeledContent(
                    "inventory.bulkMove.selectedCount",
                    value: selectedItemIDs.count.formatted()
                )
            }

            Section("inventory.bulkMove.destination.section") {
                if destinations.isEmpty {
                    ContentUnavailableView(
                        "inventory.bulkMove.destination.empty.title",
                        systemImage: "shippingbox",
                        description: Text("inventory.bulkMove.destination.empty.message")
                    )
                } else {
                    Picker(
                        "inventory.bulkMove.destination.picker",
                        selection: $selectedDestinationID
                    ) {
                        Text("inventory.bulkMove.destination.none")
                            .tag(InventoryBulkMovementDestination.Identity?.none)

                        ForEach(destinations) { destination in
                            Text(destination.displayPath)
                                .tag(Optional(destination.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("inventory.bulkMove.destinationPicker")
                }
            }

            Section {
                Button("inventory.bulkMove.review.action") {
                    prepareMove()
                }
                .disabled(selectedDestination == nil)
                .accessibilityIdentifier("inventory.bulkMove.reviewButton")
            }
        }
    }

    @ViewBuilder
    private func preflightSections(_ preflight: InventoryBulkMovementPreflight) -> some View {
        Section("inventory.bulkMove.summary.section") {
            LabeledContent(
                "inventory.bulkMove.selectedCount",
                value: preflight.selectedItemCount.formatted()
            )
            LabeledContent(
                "inventory.bulkMove.changedCount",
                value: preflight.changedItemCount.formatted()
            )
        }

        Section("inventory.bulkMove.from.section") {
            ForEach(preflight.sourceSummaries) { source in
                LabeledContent(sourceDisplayName(source.snapshot)) {
                    Text(source.itemCount.formatted())
                }
            }
        }

        Section("inventory.bulkMove.to.section") {
            Text(preflight.destination.displayPath)
        }

        Section {
            if preflight.changedItemCount == 0 {
                Text("inventory.bulkMove.unchanged.message")
                    .foregroundStyle(.secondary)

                Button("inventory.bulkMove.done") {
                    dismiss()
                }
            } else {
                Button("inventory.bulkMove.confirm.action") {
                    commit(preflight)
                }
                .accessibilityIdentifier("inventory.bulkMove.confirmButton")
            }
        }
    }

    private var selectedDestination: InventoryBulkMovementDestination? {
        guard let selectedDestinationID else { return nil }
        return destinations.first { $0.id == selectedDestinationID }
    }

    private func prepareMove() {
        guard let selectedDestination else { return }

        switch InventoryBulkMovement.prepare(
            selectedItemIDs: selectedItemIDs,
            items: items,
            locations: locations,
            places: places,
            destination: selectedDestination,
            access: premiumAccess
        ) {
        case let .ready(preflight):
            self.preflight = preflight
        case .accessRequired:
            dismissForUpgrade()
        case .emptySelection:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.emptySelection.message",
                defaultValue: "Select at least one item to move."
            )
        case .staleSelection:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.staleSelection.message",
                defaultValue: "The selected items changed. Close this sheet and select them again."
            )
        case .invalidDestination:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.invalidDestination.message",
                defaultValue: "That destination is no longer available."
            )
        }
    }

    private func commit(_ preflight: InventoryBulkMovementPreflight) {
        switch InventoryBulkMovement.commit(
            preflight,
            access: premiumAccess,
            in: modelContext
        ) {
        case .moved, .unchanged:
            dismiss()
        case .accessRequired:
            dismissForUpgrade()
        case .staleSelection:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.staleSelection.message",
                defaultValue: "The selected items changed. Close this sheet and select them again."
            )
        case .invalidDestination:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.invalidDestination.message",
                defaultValue: "That destination is no longer available."
            )
        case .cancelled:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.cancelled.message",
                defaultValue: "The move was cancelled. No items were changed."
            )
        case .failed:
            outcomeMessage = InventoryLocalization.string(
                "inventory.bulkMove.failed.message",
                defaultValue: "No items were moved. Try again."
            )
        }
    }

    private func sourceDisplayName(_ source: InventoryMovementEndpointSnapshot) -> String {
        let location = source.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationName = location.isEmpty ? InventoryLocalization.noLocation : location
        guard let place = source.placeName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !place.isEmpty
        else {
            return locationName
        }
        return "\(locationName) › \(place)"
    }

    private func dismissForUpgrade() {
        dismiss()
        onAccessRequired()
    }
}
