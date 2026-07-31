import SwiftData
import SwiftUI

struct InventoryPlaceContentsMovementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    let sourcePlaceID: UUID

    @State private var selectedDestinationID: InventoryBulkMovementDestination.Identity?
    @State private var preflight: InventoryPlaceContentsMovementPreflight?
    @State private var outcomeMessage: String?

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
                    reviewSections(preflight)
                } else {
                    destinationSections
                }
            }
            .navigationTitle(
                preflight == nil
                    ? InventoryLocalization.string(
                        "locations.placeMove.destination.title",
                        defaultValue: "Move Place Contents"
                    )
                    : InventoryLocalization.string(
                        "locations.placeMove.review.title",
                        defaultValue: "Review Move"
                    )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("locations.placeMove.cancel") {
                        dismiss()
                    }
                }

                if preflight != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("locations.placeMove.back") {
                            preflight = nil
                        }
                    }
                }
            }
            .alert(
                InventoryLocalization.string(
                    "locations.placeMove.result.title",
                    defaultValue: "Couldn’t Move Contents"
                ),
                isPresented: Binding(
                    get: { outcomeMessage != nil },
                    set: { if !$0 { outcomeMessage = nil } }
                )
            ) {
                Button("locations.placeMove.result.ok", role: .cancel) {}
            } message: {
                Text(outcomeMessage ?? "")
            }
        }
    }

    private var destinationSections: some View {
        Group {
            Section("locations.placeMove.destination.section") {
                Picker(
                    "locations.placeMove.destination.picker",
                    selection: $selectedDestinationID
                ) {
                    Text("locations.placeMove.destination.none")
                        .tag(InventoryBulkMovementDestination.Identity?.none)

                    ForEach(destinations) { destination in
                        Text(destination.displayPath)
                            .tag(Optional(destination.id))
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("locations.placeMove.destinationPicker")
            }

            Section {
                Button("locations.placeMove.review.action") {
                    prepareMove()
                }
                .disabled(selectedDestination == nil)
                .accessibilityIdentifier("locations.placeMove.reviewButton")
            }
        }
    }

    @ViewBuilder
    private func reviewSections(_ preflight: InventoryPlaceContentsMovementPreflight) -> some View {
        Section("locations.placeMove.summary.section") {
            LabeledContent(
                "locations.placeMove.itemCount",
                value: preflight.itemCount.formatted()
            )
        }

        Section("locations.placeMove.from.section") {
            Text(preflight.source.displayPath)
        }

        Section("locations.placeMove.to.section") {
            Text(preflight.movement.destination.displayPath)
        }

        Section {
            if preflight.movement.changedItemCount == 0 {
                Text("locations.placeMove.unchanged.message")
                    .foregroundStyle(.secondary)

                Button("locations.placeMove.done") {
                    dismiss()
                }
            } else {
                Button("locations.placeMove.confirm.action") {
                    commit(preflight)
                }
                .accessibilityIdentifier("locations.placeMove.confirmButton")
            }
        }
    }

    private var selectedDestination: InventoryBulkMovementDestination? {
        guard let selectedDestinationID else { return nil }
        return destinations.first { $0.id == selectedDestinationID }
    }

    private func prepareMove() {
        guard let selectedDestination else { return }

        switch InventoryPlaceContentsMovement.prepare(
            sourcePlaceID: sourcePlaceID,
            items: items,
            locations: locations,
            places: places,
            destination: selectedDestination,
            access: premiumAccess
        ) {
        case let .ready(preflight):
            self.preflight = preflight
        case .emptyPlace:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.empty.message",
                defaultValue: "This Storage Place has no items to move."
            )
        case .accessRequired:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.accessRequired.message",
                defaultValue: "Moving all items from a Storage Place requires additional access."
            )
        case .invalidSource:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.sourceChanged.message",
                defaultValue: "This Storage Place changed. Close this sheet and review it again."
            )
        case .invalidDestination:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.invalidDestination.message",
                defaultValue: "That destination is no longer available."
            )
        }
    }

    private func commit(_ preflight: InventoryPlaceContentsMovementPreflight) {
        switch InventoryPlaceContentsMovement.commit(
            preflight,
            access: premiumAccess,
            in: modelContext
        ) {
        case .moved, .unchanged:
            dismiss()
        case .accessRequired:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.accessRequired.message",
                defaultValue: "Moving all items from a Storage Place requires additional access."
            )
        case .sourceChanged:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.sourceChanged.message",
                defaultValue: "The Storage Place contents changed. Review the move again."
            )
        case .invalidDestination:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.invalidDestination.message",
                defaultValue: "That destination changed or is no longer available. Review the move again."
            )
        case .cancelled:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.cancelled.message",
                defaultValue: "The move was cancelled. No items were changed."
            )
        case .failed:
            outcomeMessage = InventoryLocalization.string(
                "locations.placeMove.failed.message",
                defaultValue: "No items were moved. Try again."
            )
        }
    }
}
