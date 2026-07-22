import SwiftUI

struct InventoryEmptyStateView: View {
    let viewModel: InventoryEmptyStateViewModel
    let onAddItem: () -> Void

    init(viewModel: InventoryEmptyStateViewModel, onAddItem: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onAddItem = onAddItem
    }

    var body: some View {
        InventoryEmptyStateScreen {
            InventoryEmptyStateCard(
                title: viewModel.title,
                message: viewModel.message,
                systemImage: "shippingbox"
            ) {
                Button(viewModel.primaryActionTitle) {
                    onAddItem()
                }
                .inventoryEmptyStatePrimaryAction()
                .accessibilityIdentifier("inventory.empty.addItemButton")
            }
        }
    }
}

#if DEBUG
#Preview("Empty State - Light") {
    InventoryEmptyStateView(viewModel: .initial)
        .preferredColorScheme(.light)
}

#Preview("Empty State - Dark") {
    InventoryEmptyStateView(viewModel: .initial)
        .preferredColorScheme(.dark)
}

#Preview("Empty State - Accessibility Ukrainian") {
    InventoryEmptyStateView(
        viewModel: InventoryEmptyStateViewModel(
            title: "Поки що немає збережених речей",
            message: "Додайте речі, локації й точні місця, щоб швидко знаходити потрібне пізніше.",
            primaryActionTitle: "Додати річ"
        )
    )
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
