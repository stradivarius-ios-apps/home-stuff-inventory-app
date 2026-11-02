import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryAppearanceTests {
    private let roleNames = [
        "InventoryGroupedBackground",
        "InventoryLocationAtmosphere",
        "InventoryContentSurface",
        "InventoryContentStroke",
        "InventoryStorageAccent",
        "InventoryPlaceAccent",
        "InventoryPrimaryAction",
        "InventorySecondaryAccent",
        "InventoryContextHighlight",
        "InventoryBrandText"
    ]

    @Test func semanticRolesProvideLightDarkAndHighContrastValues() throws {
        let expectedAppearances: Set<String> = [
            "default",
            "contrast:high",
            "luminosity:dark",
            "contrast:high|luminosity:dark"
        ]

        for roleName in roleNames {
            let colorSet = try loadColorSet(named: roleName)
            let appearances = Set(colorSet.colors.map(\.appearanceKey))

            #expect(appearances == expectedAppearances, "Incomplete appearances for \(roleName): \(appearances)")
            #expect(
                colorSet.colors.allSatisfy { $0.color.components.alpha == "1.000" },
                "Semantic role \(roleName) must remain opaque"
            )
        }
    }

    @Test func accentsRemainDistinctInEveryAppearance() throws {
        let accentNames = [
            "InventoryStorageAccent",
            "InventoryPlaceAccent",
            "InventoryPrimaryAction",
            "InventorySecondaryAccent",
            "InventoryContextHighlight",
            "InventoryBrandText"
        ]
        let colorSets = try accentNames.map(loadColorSet(named:))
        let appearanceKeys = try #require(colorSets.first).colors.map(\.appearanceKey)

        for appearanceKey in appearanceKeys {
            let signatures = try colorSets.map { colorSet in
                try #require(colorSet.colors.first { $0.appearanceKey == appearanceKey }).color.components.signature
            }

            #expect(Set(signatures).count == accentNames.count, "Accent roles collapsed for \(appearanceKey)")
        }
    }

    @Test func adaptivePaletteMatchesReferenceValues() throws {
        let referenceURL = try repositoryRootURL()
            .appendingPathComponent("docs/design/references/design-code-v1/design-tokens.json")
        let reference = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any]
        )
        let colors = try #require(reference["colors"] as? [String: Any])
        let roles = try #require(colors["roles"] as? [[String: Any]])
        let mappings = [
            "location": "InventoryStorageAccent",
            "storagePlace": "InventoryPlaceAccent",
            "item": "InventorySecondaryAccent",
            "primaryAction": "InventoryPrimaryAction",
            "context": "InventoryContextHighlight",
            "brandText": "InventoryBrandText",
            "background": "InventoryGroupedBackground",
            "surface": "InventoryContentSurface",
            "stroke": "InventoryContentStroke",
            "locationAtmosphere": "InventoryLocationAtmosphere"
        ]
        let appearanceNames = [
            "default": "light",
            "luminosity:dark": "dark",
            "contrast:high": "increasedContrastLight",
            "contrast:high|luminosity:dark": "increasedContrastDark"
        ]

        for (role, assetName) in mappings {
            let values = try #require(roles.first { $0["name"] as? String == role } ?? colors[role] as? [String: Any])
            for definition in try loadColorSet(named: assetName).colors {
                let name = try #require(appearanceNames[definition.appearanceKey])
                let expected = try #require(values[name] as? String)
                #expect(definition.color.components.hex == expected, "\(assetName) \(name)")
            }
        }
    }

    @Test func opaqueAccentsKeepReadableContrastOnContentAndGroupedSurfaces() throws {
        let surfaces = try ["InventoryGroupedBackground", "InventoryContentSurface"].map(loadColorSet(named:))
        for name in ["InventoryStorageAccent", "InventoryPlaceAccent", "InventorySecondaryAccent",
                     "InventoryPrimaryAction", "InventoryContextHighlight", "InventoryBrandText"] {
            for accent in try loadColorSet(named: name).colors {
                for surface in surfaces {
                    let background = try #require(surface.colors.first { $0.appearanceKey == accent.appearanceKey })
                    let luminances = [accent.color.components.luminance, background.color.components.luminance].sorted()
                    let ratio = (luminances[1] + 0.05) / (luminances[0] + 0.05)
                    #expect(ratio >= 4.5, "\(name) \(accent.appearanceKey): \(ratio)")
                }
            }
        }
    }

    @Test func globalAccentColorRemainsOutsideThePrimaryActionPalette() throws {
        let accentColor = try loadColorSet(named: "AccentColor")
        let primaryAction = try loadColorSet(named: "InventoryPrimaryAction")

        #expect(accentColor.colors.count == 1)
        #expect(accentColor.colors[0].color.components.signature == "0.120:0.420:0.360:1.000")
        #expect(!primaryAction.colors.contains { $0.color.components.signature == accentColor.colors[0].color.components.signature })
    }

    @Test func contentSemanticsMapToShippedAccentRoles() {
        #expect(InventoryDesign.ContentRole.item.accentRole == .secondary)
        #expect(InventoryDesign.ContentRole.location.accentRole == .storage)
        #expect(InventoryDesign.ContentRole.place.accentRole == .place)
    }

    @Test func contentGlyphPresentationsKeepTheirFixedSizes() {
        #expect(InventoryDesign.contentGlyphSize == 32)
        #expect(InventoryDesign.identityContentGlyphSize == 40)
    }

    @Test func contentSemanticsResolveShippedIdentityAndSurfaceColors() {
        #expect(InventoryDesign.ContentRole.item.color == InventoryDesign.Appearance.secondaryAccent)
        #expect(InventoryDesign.ContentRole.location.color == InventoryDesign.Appearance.storageAccent)
        #expect(InventoryDesign.ContentRole.place.color == InventoryDesign.Appearance.placeAccent)

        #expect(InventoryDesign.ContentRole.item.surfaceTint == InventoryDesign.Appearance.secondaryAccent)
        #expect(InventoryDesign.ContentRole.location.surfaceTint == InventoryDesign.Appearance.locationAtmosphere)
        #expect(InventoryDesign.ContentRole.place.surfaceTint == InventoryDesign.Appearance.placeAccent)

        #expect(InventoryDesign.SurfaceRole.item.tint == InventoryDesign.ContentRole.item.surfaceTint)
        #expect(InventoryDesign.SurfaceRole.location.tint == InventoryDesign.ContentRole.location.surfaceTint)
        #expect(InventoryDesign.SurfaceRole.place.tint == InventoryDesign.ContentRole.place.surfaceTint)
        #expect(InventoryDesign.SurfaceRole.context.tint == InventoryDesign.Appearance.contextHighlight)
        #expect(InventoryDesign.SurfaceRole.neutral.tint == InventoryDesign.Appearance.contentStroke)
    }

    @Test func locationManagementUsesLocationSemanticsWithoutChangingCategoryDefaults() {
        #expect(InventoryListManagementScope.locations.contentRole == .location)
        #expect(InventoryListManagementScope.locations.managedValueIconRole == .storage)
        #expect(InventoryListManagementScope.categories.contentRole == nil)
        #expect(InventoryListManagementScope.categories.managedValueIconRole == .secondary)

        let defaultRow = managedValueRow()
        let locationRow = managedValueRow(iconRole: .storage)

        #expect(defaultRow.iconRole == .secondary)
        #expect(locationRow.iconRole == .storage)
    }

    private func managedValueRow(
        iconRole: InventoryDesign.AccentRole = .secondary
    ) -> InventoryManagedValueRow {
        InventoryManagedValueRow(
            title: "Test value",
            systemImage: "tag",
            iconRole: iconRole,
            itemCount: 0,
            isEditable: true,
            viewItemsAccessibilityLabel: nil,
            viewItemsAction: nil,
            editActionLabel: "Edit",
            editAction: {},
            deleteAction: {}
        )
    }

    private func loadColorSet(named name: String) throws -> InventoryColorSet {
        let url = try repositoryRootURL()
            .appendingPathComponent("HomeStuffInventoryApp/Resources/Assets.xcassets", isDirectory: true)
            .appendingPathComponent("\(name).colorset/Contents.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(InventoryColorSet.self, from: data)
    }

    private func repositoryRootURL() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)

        while url.path != "/" {
            url.deleteLastPathComponent()

            if FileManager.default.fileExists(atPath: url.appendingPathComponent("AGENTS.md").path),
               FileManager.default.fileExists(atPath: url.appendingPathComponent("HomeStuffInventoryApp.xcodeproj").path) {
                return url
            }
        }

        throw InventoryAppearanceTestError.repositoryRootNotFound
    }
}

private struct InventoryColorSet: Decodable {
    let colors: [InventoryColorDefinition]
}

private struct InventoryColorDefinition: Decodable {
    let appearances: [InventoryColorAppearance]?
    let color: InventoryColorPayload

    var appearanceKey: String {
        guard let appearances, !appearances.isEmpty else {
            return "default"
        }

        return appearances
            .map { "\($0.appearance):\($0.value)" }
            .sorted()
            .joined(separator: "|")
    }
}

private struct InventoryColorAppearance: Decodable {
    let appearance: String
    let value: String
}

private struct InventoryColorPayload: Decodable {
    let components: InventoryColorComponents
}

private struct InventoryColorComponents: Decodable {
    let alpha: String
    let blue: String
    let green: String
    let red: String

    var hex: String {
        "#" + [red, green, blue].map { String(format: "%02X", Int((Double($0)! * 255).rounded())) }.joined()
    }

    var luminance: Double {
        let channels = [red, green, blue].map { value in
            let channel = Double(value)!
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }

    var signature: String {
        [red, green, blue, alpha].joined(separator: ":")
    }
}

private enum InventoryAppearanceTestError: Error {
    case repositoryRootNotFound
}
