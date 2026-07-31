import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumUpgradeCoordinator.self) private var coordinator

    let context: PremiumUpgradeContext

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(context.titleKey))
                            .font(.title2.bold())
                        Text(LocalizedStringKey(context.messageKey))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("premium.bundle.section") {
                    ForEach(PremiumBundleCapability.allCases, id: \.self) { capability in
                        Label(
                            LocalizedStringKey(capability.titleKey),
                            systemImage: capability.systemImage
                        )
                    }
                }

                productSection
                outcomeSection
            }
            .navigationTitle("premium.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("premium.dismiss") {
                        coordinator.dismiss()
                        dismiss()
                    }
                }
            }
            .task {
                await coordinator.loadProductIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var productSection: some View {
        Section {
            if coordinator.premiumAccess.entitlements.hasLocalProFeatures {
                Label("premium.owned", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("premium.owned")
            } else {
                switch coordinator.productState {
                case let .available(product):
                    LabeledContent {
                        Text(product.displayPrice)
                    } label: {
                        Text(product.displayName)
                    }

                    Text("premium.oneTime")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await coordinator.purchase() }
                    } label: {
                        operationLabel(
                            idleKey: "premium.purchase",
                            isProgressing: coordinator.operationState == .purchasing
                        )
                    }
                    .disabled(coordinator.operationState == .purchasing)
                    .accessibilityIdentifier("premium.purchase")
                case .idle, .loading:
                    ProgressView("premium.loading")
                case .unavailable:
                    Text("premium.productUnavailable")
                        .foregroundStyle(.secondary)
                case .error:
                    Text("premium.offline")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await coordinator.restore() }
            } label: {
                operationLabel(
                    idleKey: "premium.restore",
                    isProgressing: coordinator.operationState == .restoring
                )
            }
            .disabled(coordinator.operationState == .restoring)
            .accessibilityIdentifier("premium.restore")
        }
    }

    @ViewBuilder
    private var outcomeSection: some View {
        switch coordinator.outcome {
        case .none:
            EmptyView()
        case .pending:
            Section {
                Label("premium.outcome.pending", systemImage: "clock")
            }
        case .failure:
            Section {
                Label("premium.outcome.failure", systemImage: "exclamationmark.triangle")
            }
        case .offline:
            Section {
                Label("premium.offline", systemImage: "wifi.slash")
            }
        case .productUnavailable:
            Section {
                Label("premium.productUnavailable", systemImage: "cart.badge.questionmark")
            }
        case .restoreNoPurchase:
            Section {
                Label("premium.outcome.noPurchase", systemImage: "magnifyingglass")
            }
        case .restored:
            Section {
                Label("premium.outcome.restored", systemImage: "checkmark.circle")
            }
        }
    }

    private func operationLabel(
        idleKey: LocalizedStringKey,
        isProgressing: Bool
    ) -> some View {
        HStack {
            Text(idleKey)
            Spacer()
            if isProgressing {
                ProgressView()
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private extension PremiumBundleCapability {
    var systemImage: String {
        switch self {
        case .roomSweep: "square.stack.3d.up"
        case .selectedItemMovement: "checklist"
        case .placeContentsMovement: "shippingbox.and.arrow.forward"
        case .extendedMovementUndo: "arrow.uturn.backward.circle"
        case .nestedStoragePlaces: "square.3.layers.3d"
        }
    }
}
