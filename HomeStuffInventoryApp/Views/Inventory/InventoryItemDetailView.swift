import os
import SwiftData
import SwiftUI

struct InventoryItemDetailView: View {
    private static let recentViewLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HomeStuffInventoryApp",
        category: "RecentItemViews"
    )

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: InventoryItem
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    @State private var isShowingItemForm = false
    @State private var isShowingDeleteConfirmation = false
    @State private var mutationFailure: InventoryItemMutationFailure?
    @State private var isShowingNotesEditor = false
    @State private var isShowingNavigationTitle = false
    @State private var hasRecordedRecentView = false
    @State private var isShowingMovementHistory = false

    private var viewModel: InventoryItemDetailViewModel {
        InventoryItemDetailViewModel(item: item, places: places)
    }

    var body: some View {
        ZStack {
            ScrollView {
                    VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                        InventoryItemDetailIdentityHeader(viewModel: viewModel)
                            .inventoryHeroNavigationTitleVisibilityAnchor()

                        InventoryDetailStorageAnswerCard(viewModel: viewModel)

                        InventoryDetailPropertiesCard(viewModel: viewModel)

                        InventoryDetailNotesCard(notes: item.notes) {
                            isShowingNotesEditor = true
                        }

                        if !viewModel.tags.isEmpty {
                            InventoryDetailTagsCard(tags: viewModel.tags)
                        }

                        InventoryDetailDatesCard(viewModel: viewModel)

                        Button {
                            isShowingMovementHistory = true
                        } label: {
                            Label("premium.history.title", systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("inventory.itemDetail.movementHistory")

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("inventory.action.deleteItem", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("inventory.deleteItemButton")
                        .padding(.top, InventoryDesign.screenPadding)

                        Color.clear
                            .frame(height: InventoryHeroNavigationTitleMetrics.bottomScrollReserve)
                            .accessibilityHidden(true)
                    }
                    .inventoryDetailContentWidth()
                    .padding(.top, detailTopPadding)
                }
                .inventoryScrollContentClearance()
                .accessibilityIdentifier("inventory.itemDetail")
                .accessibilityValue(isShowingNavigationTitle ? viewModel.name : "")
                .inventoryHeroNavigationTitleVisibilityObserver(
                    isShowingNavigationTitle: $isShowingNavigationTitle,
                    restingAnchorMinY: detailTopPadding
                )
        }
        .inventoryGroupedBackground()
        .navigationTitle(isShowingNavigationTitle ? viewModel.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItemForm = true
                } label: {
                    Label("inventory.action.editItem", systemImage: "pencil")
                }
                .inventoryPrimaryActionTint()
                .accessibilityIdentifier("inventory.editItemButton")
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView(item: item)
        }
        .sheet(isPresented: $isShowingNotesEditor) {
            InventoryNotesEditorView(item: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $isShowingMovementHistory) {
            InventoryMovementHistoryView(itemID: item.id)
        }
        .alert("inventory.alert.delete.title", isPresented: $isShowingDeleteConfirmation) {
            Button("inventory.action.delete", role: .destructive) {
                deleteItem()
            }
            .accessibilityIdentifier("inventory.confirmDeleteButton")

            Button("inventory.action.cancel", role: .cancel) { }
        } message: {
            Text(
                InventoryLocalization.formatted(
                    "inventory.alert.delete.message",
                    defaultValue: "This removes %@ from your inventory.",
                    viewModel.name
                )
            )
        }
        .alert(mutationFailure?.title ?? "", isPresented: isShowingMutationFailure) {
            Button("inventory.action.ok", role: .cancel) { }
        } message: {
            Text(mutationFailure?.message ?? "")
        }
        .onAppear {
            recordRecentViewIfNeeded()
        }
    }

    private var detailTopPadding: CGFloat {
        colorScheme == .dark ? InventoryDesign.screenPadding : InventoryDesign.gridSpacing
    }

    private var isShowingMutationFailure: Binding<Bool> {
        Binding(
            get: { mutationFailure != nil },
            set: { isShowing in
                if !isShowing {
                    mutationFailure = nil
                }
            }
        )
    }

    private func recordRecentViewIfNeeded() {
        guard !hasRecordedRecentView else {
            return
        }

        hasRecordedRecentView = true

        do {
            try InventoryRecentItemViews.recordView(of: item, in: modelContext.container)
        } catch {
            Self.recentViewLogger.error("Unable to record recent item view: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteItem() {
        do {
            try InventoryItemMutationPersistence.delete(item, in: modelContext)
            dismiss()
        } catch {
            mutationFailure = .deleteItem
        }
    }
}
