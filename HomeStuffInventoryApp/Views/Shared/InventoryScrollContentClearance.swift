import SwiftUI

extension View {
    /// Keeps the end of native scroll content clear of persistent system chrome without guessing its height.
    func inventoryScrollContentClearance() -> some View {
        contentMargins(.bottom, InventoryDesign.screenPadding, for: .scrollContent)
    }
}
