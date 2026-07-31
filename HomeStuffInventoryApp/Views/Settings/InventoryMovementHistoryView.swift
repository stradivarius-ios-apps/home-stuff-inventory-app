import SwiftData
import SwiftUI

struct InventoryMovementHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess

    @Query(sort: \InventoryMovementRecord.occurredAt, order: .reverse)
    private var records: [InventoryMovementRecord]
    @Query private var items: [InventoryItem]
    @Query private var locations: [StorageLocation]
    @Query private var places: [InventoryPlace]

    @State private var outcomeKey: String?

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    ContentUnavailableView(
                        "premium.history.empty.title",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("premium.history.empty.message")
                    )
                } else {
                    Section {
                        ForEach(records) { record in
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

                    Section {
                        Button("premium.history.undo") {
                            undoLatest()
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("premium.history.undo")
                    } footer: {
                        Text("premium.history.undo.footer")
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
        }
    }

    private func itemName(for record: InventoryMovementRecord) -> String {
        items.first(where: { $0.id == record.itemID })?.name
            ?? InventoryLocalization.string(
                "premium.history.unknownItem",
                defaultValue: "Removed Item"
            )
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
        outcomeKey = switch outcome {
        case .undone: "premium.history.outcome.undone"
        case .currentStateChanged: "premium.history.outcome.changed"
        case .unsafeRestoration: "premium.history.outcome.unsafe"
        case .accessRequired: "premium.history.outcome.access"
        case .unavailable: "premium.history.outcome.unavailable"
        case .failed: "premium.history.outcome.failed"
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
