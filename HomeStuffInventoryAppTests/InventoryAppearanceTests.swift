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
        "InventoryContextHighlight"
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
            "InventoryContextHighlight"
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

    @Test func approvedLightSurfaceSignaturesAndDarkBaselinesRemainExact() throws {
        let expectedSignatures = [
            "InventoryGroupedBackground": [
                "default": "0.949:0.941:0.957:1.000",
                "contrast:high": "0.925:0.914:0.937:1.000",
                "luminosity:dark": "0.090:0.086:0.114:1.000",
                "contrast:high|luminosity:dark": "0.063:0.059:0.078:1.000"
            ],
            "InventoryContentSurface": [
                "default": "0.984:0.980:0.988:1.000",
                "contrast:high": "1.000:1.000:1.000:1.000",
                "luminosity:dark": "0.141:0.145:0.173:1.000",
                "contrast:high|luminosity:dark": "0.169:0.173:0.204:1.000"
            ],
            "InventoryLocationAtmosphere": [
                "default": "0.882:0.945:0.929:1.000",
                "contrast:high": "0.847:0.925:0.906:1.000",
                "luminosity:dark": "0.063:0.161:0.165:1.000",
                "contrast:high|luminosity:dark": "0.043:0.133:0.137:1.000"
            ]
        ]

        for (roleName, expected) in expectedSignatures {
            let colorSet = try loadColorSet(named: roleName)
            let actual = Dictionary(
                uniqueKeysWithValues: colorSet.colors.map { definition in
                    (definition.appearanceKey, definition.color.components.signature)
                }
            )

            #expect(actual == expected)
        }
    }

    @Test func placeAccentMatchesApprovedPalette() throws {
        let expectedSignatures = [
            "default": "0.455:0.357:0.518:1.000",
            "luminosity:dark": "0.788:0.698:0.835:1.000",
            "contrast:high": "0.337:0.239:0.400:1.000",
            "contrast:high|luminosity:dark": "0.906:0.824:0.937:1.000"
        ]
        let colorSet = try loadColorSet(named: "InventoryPlaceAccent")
        let actualSignatures = Dictionary(
            uniqueKeysWithValues: colorSet.colors.map { definition in
                (definition.appearanceKey, definition.color.components.signature)
            }
        )

        #expect(actualSignatures == expectedSignatures)
    }

    @Test func primaryActionMatchesApprovedBrandIndigoPalette() throws {
        let expectedSignatures = [
            "default": "0.400:0.329:0.761:1.000",
            "luminosity:dark": "0.659:0.608:1.000:1.000",
            "contrast:high": "0.294:0.224:0.624:1.000",
            "contrast:high|luminosity:dark": "0.788:0.757:1.000:1.000"
        ]
        let colorSet = try loadColorSet(named: "InventoryPrimaryAction")
        let actualSignatures = Dictionary(
            uniqueKeysWithValues: colorSet.colors.map { definition in
                (definition.appearanceKey, definition.color.components.signature)
            }
        )

        #expect(actualSignatures == expectedSignatures)
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

    var signature: String {
        [red, green, blue, alpha].joined(separator: ":")
    }
}

private enum InventoryAppearanceTestError: Error {
    case repositoryRootNotFound
}
