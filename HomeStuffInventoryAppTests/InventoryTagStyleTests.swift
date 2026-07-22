import Testing
@testable import HomeStuffInventoryApp

struct InventoryTagStyleTests {
    @Test func tintTokenIsDeterministicForMatchingTags() {
        let firstToken = InventoryTagStyle.tintToken(for: "  USB Cables  ")
        let secondToken = InventoryTagStyle.tintToken(for: "usb   cables")

        #expect(firstToken == secondToken)
    }

    @Test func tintTokenNormalizesCaseDiacriticsWidthAndWhitespace() {
        let firstToken = InventoryTagStyle.tintToken(for: "  Étagère   Maison ")
        let secondToken = InventoryTagStyle.tintToken(for: "etagere maison")

        #expect(firstToken == secondToken)
    }

    @Test func emptyTagsUseFirstPaletteToken() {
        #expect(InventoryTagStyle.tintToken(for: "  \n ") == InventoryTagStyle.TintToken.allCases[0])
    }

    @Test func stablePaletteIndexStaysWithinPalette() {
        let tags = [
            "tools",
            "travel",
            "документи",
            "дуже довгий український тег для органайзера",
            "Cables & Adapters"
        ]

        for tag in tags {
            let index = InventoryTagStyle.stablePaletteIndex(for: InventoryTagStyle.normalizedTag(tag))

            #expect(index >= 0)
            #expect(index < InventoryTagStyle.TintToken.allCases.count)
        }
    }
}
