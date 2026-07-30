import SwiftUI

struct RootView: View {
    @State private var inventorySearchText = ""
    @State private var selectedTab: RootTab = .locations

    var body: some View {
        if #available(iOS 18.0, *) {
            SearchRoleRootTabView(
                inventorySearchText: $inventorySearchText,
                selectedTab: $selectedTab
            )
        } else {
            LegacyRootTabView(inventorySearchText: $inventorySearchText)
        }
    }
}

private enum RootTab: Hashable {
    case inventory
    case locations
    case settings
    case search
}

@available(iOS 18.0, *)
private struct SearchRoleRootTabView: View {
    @Binding var inventorySearchText: String
    @Binding var selectedTab: RootTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("locations.title", systemImage: "map", value: .locations) {
                NavigationStack {
                    LocationsListView()
                }
            }

            Tab("inventory.title", systemImage: "list.bullet", value: .inventory) {
                NavigationStack {
                    InventoryListView(presentation: .compactInventory)
                }
            }

            Tab("settings.title", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsHomeView()
                }
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    InventoryListView(
                        searchText: $inventorySearchText,
                        presentation: .searchResults
                    )
                        .searchable(
                            text: $inventorySearchText,
                            placement: .automatic,
                            prompt: "inventory.search.prompt"
                        )
                }
            } label: {
                Label("inventory.search.prompt", systemImage: "magnifyingglass")
            }
        }
        .inventorySearchTabActivation()
    }
}

private struct LegacyRootTabView: View {
    @Binding var inventorySearchText: String

    var body: some View {
        TabView {
            NavigationStack {
                LocationsListView()
            }
            .tabItem {
                Label("locations.title", systemImage: "map")
            }
            .accessibilityLabel("locations.tab.accessibilityLabel")

            NavigationStack {
                InventoryListView(
                    searchText: $inventorySearchText,
                    presentation: .searchResults
                )
                    .searchable(
                        text: $inventorySearchText,
                        placement: .automatic,
                        prompt: "inventory.search.prompt"
                    )
            }
            .tabItem {
                Label("inventory.title", systemImage: "list.bullet")
            }
            .accessibilityLabel("inventory.tab.accessibilityLabel")

            NavigationStack {
                SettingsHomeView()
            }
            .tabItem {
                Label("settings.title", systemImage: "gearshape")
            }
            .accessibilityLabel("settings.tab.accessibilityLabel")
        }
    }
}

private extension View {
    @ViewBuilder
    func inventorySearchTabActivation() -> some View {
        if #available(iOS 26.0, *) {
            tabViewSearchActivation(.searchTabSelection)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .modelContainer(try! InventoryModelContainer.makeSample())
        .environment(
            PremiumAccessState(
                entitlements: .init(
                    ownsLifetimePro: true,
                    hasActiveFamilySubscription: false
                )
            )
        )
}
#endif
