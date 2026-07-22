import SwiftData
import SwiftUI

struct InventoryBackupRestorePreflightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: InventoryBackupRestorePlan
    let onCompletion: (Result<Void, InventoryBackupRestoreError>) -> Void

    @State private var isRestoring = false
    @State private var restoreTask: Task<Void, Never>?

    private let restoreService = InventoryBackupRestoreService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    summaryRow("settings.restore.preflight.items", value: plan.counts.items)
                    summaryRow("settings.restore.preflight.locations", value: plan.counts.locations)
                    summaryRow("settings.restore.preflight.places", value: plan.counts.places)
                    summaryRow("settings.restore.preflight.categories", value: plan.counts.customCategories)
                    summaryRow("settings.restore.preflight.recentViews", value: plan.counts.recentItemViews)
                } header: {
                    Text("settings.restore.preflight.contents")
                }

                Section {
                    LabeledContent("settings.restore.preflight.backupDate") {
                        Text(plan.backupDate, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("settings.restore.preflight.appVersion", value: plan.appVersion)
                    LabeledContent(
                        "settings.restore.preflight.schemaVersion",
                        value: String(plan.schemaVersion)
                    )
                } header: {
                    Text("settings.restore.preflight.backupDetails")
                }

                if !plan.compatibilityWarnings.isEmpty {
                    Section {
                        Label("settings.restore.preflight.warning.newerApp", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("settings.restore.preflight.compatibility")
                    }
                }

                Section {
                    Text("settings.restore.preflight.replacementExplanation")
                        .foregroundStyle(.secondary)

                    Button("settings.restore.preflight.confirm", role: .destructive) {
                        restore()
                    }
                    .disabled(isRestoring)
                    .accessibilityHint("settings.restore.preflight.confirm.accessibilityHint")
                    .accessibilityIdentifier("settings.restore.confirm")
                } header: {
                    Text("settings.restore.preflight.replacementHeader")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("settings.restore.preflight.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.restore.preflight.cancel") { dismiss() }
                        .disabled(isRestoring)
                }
            }
            .overlay {
                if isRestoring {
                    ProgressView("settings.restore.progress")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("settings.restore.progress")
                }
            }
            .interactiveDismissDisabled(isRestoring)
        }
        .onDisappear {
            restoreTask?.cancel()
            restoreTask = nil
        }
    }

    private func summaryRow(_ key: LocalizedStringKey, value: Int) -> some View {
        LabeledContent(key, value: value.formatted())
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        restoreTask = Task {
            do {
                _ = try await restoreService.restore(plan, in: modelContext)
                onCompletion(.success(()))
                dismiss()
            } catch is CancellationError {
                isRestoring = false
            } catch let error as InventoryBackupRestoreError {
                onCompletion(.failure(error))
                dismiss()
            } catch {
                onCompletion(.failure(.replacementFailed))
                dismiss()
            }
        }
    }
}
