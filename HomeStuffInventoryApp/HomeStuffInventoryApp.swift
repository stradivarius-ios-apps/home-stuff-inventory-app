import SwiftData
import SwiftUI

@main
struct HomeStuffInventoryApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var bootstrap = InventoryAppBootstrapState()
    @State private var entitlementService = StoreKitEntitlementService.live()
#if DEBUG
    private let qaAppearance = InventoryQAAppearanceConfiguration(
        arguments: ProcessInfo.processInfo.arguments
    )
    private let qaAccessibility = InventoryQAAccessibilityConfiguration.current
#endif

    var body: some Scene {
        WindowGroup {
            InventoryAppBootstrapView(bootstrap: bootstrap)
                .environment(entitlementService.premiumAccess)
                .task {
                    entitlementService.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        entitlementService.start()
                    case .background:
                        entitlementService.stop()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
#if DEBUG
                .preferredColorScheme(qaAppearance.colorScheme)
                .modifier(
                    InventoryQADifferentiateWithoutColorModifier(
                        isForced: qaAccessibility.differentiateWithoutColor
                    )
                )
                .overlay {
                    if qaAppearance.installsMarker {
                        InventoryQAAppearanceMarker()
                    }
                }
                .overlay {
                    if let markerIdentifier = qaAccessibility.markerIdentifier {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityIdentifier(markerIdentifier)
                            .allowsHitTesting(false)
                    }
                }
#endif
        }
    }
}

#if DEBUG
private struct InventoryQAAppearanceConfiguration {
    let colorScheme: ColorScheme?

    init(arguments: [String]) {
        if arguments.contains("--qa-force-light-appearance") {
            colorScheme = .light
        } else if arguments.contains("--qa-force-dark-appearance") {
            colorScheme = .dark
        } else {
            colorScheme = nil
        }
    }

    var installsMarker: Bool {
        colorScheme != nil
    }
}

private struct InventoryQAAppearanceMarker: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("qa.appearance.\(colorScheme == .dark ? "dark" : "light")")
            .allowsHitTesting(false)
    }
}

private struct InventoryQADifferentiateWithoutColorKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var inventoryQADifferentiateWithoutColor: Bool {
        get { self[InventoryQADifferentiateWithoutColorKey.self] }
        set { self[InventoryQADifferentiateWithoutColorKey.self] = newValue }
    }
}

private struct InventoryQADifferentiateWithoutColorModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemValue

    let isForced: Bool

    func body(content: Content) -> some View {
        let observedValue = systemValue || isForced

        content
            .overlay {
                InventoryQADifferentiateWithoutColorMarker()
            }
            .environment(\.inventoryQADifferentiateWithoutColor, observedValue)
    }
}

private struct InventoryQADifferentiateWithoutColorMarker: View {
    @Environment(\.inventoryQADifferentiateWithoutColor) private var observedValue

    var body: some View {
        if observedValue {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("qa.accessibility.differentiateWithoutColor")
                .allowsHitTesting(false)
        }
    }
}

struct InventoryQAAccessibilityConfiguration {
    private static let reduceMotionArgument = "--qa-reduce-motion"
    private static let reduceTransparencyArgument = "--qa-reduce-transparency"
    private static let increaseContrastArgument = "--qa-increase-contrast"
    private static let differentiateWithoutColorArgument = "--qa-differentiate-without-color"

    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool

    static var current: Self {
        let arguments = ProcessInfo.processInfo.arguments
        return Self(
            reduceMotion: arguments.contains(reduceMotionArgument),
            reduceTransparency: arguments.contains(reduceTransparencyArgument),
            increaseContrast: arguments.contains(increaseContrastArgument),
            differentiateWithoutColor: arguments.contains(differentiateWithoutColorArgument)
        )
    }

    var markerIdentifier: String? {
        if reduceMotion {
            "qa.accessibility.reduceMotion"
        } else if reduceTransparency {
            "qa.accessibility.reduceTransparency"
        } else if increaseContrast {
            "qa.accessibility.increaseContrast"
        } else {
            nil
        }
    }
}
#endif
