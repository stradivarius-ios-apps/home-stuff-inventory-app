import ImageIO
import Testing
import UIKit
@testable import HomeStuffInventoryApp

struct InventoryGlyphTests {
    @Test func contentMappingsRetainTheirDomainMeaning() {
        #expect(InventoryGlyph.resolve(systemName: "desktopcomputer", domain: .location) == .office)
        #expect(InventoryGlyph.resolve(systemName: "desktopcomputer", domain: .item) == .desktopComputer)
        #expect(InventoryGlyph.resolve(systemName: "fork.knife", domain: .location) == .kitchen)
        #expect(InventoryGlyph.resolve(systemName: "fork.knife", domain: .item) == .cutlery)
        #expect(InventoryGlyph.resolve(systemName: "square.grid.2x2", domain: .location) == .roomFloorplan)
        #expect(InventoryGlyph.resolve(systemName: "square.grid.2x2", domain: .place) == .organizer)
        #expect(InventoryGlyph.resolve(systemName: "hanger", domain: .location) == .cabinet)
        #expect(InventoryGlyph.resolve(systemName: "hanger", domain: .place) == .hanger)
        #expect(InventoryGlyph.resolve(systemName: "cabinet.fill", domain: .place) == .drawer)
        #expect(InventoryGlyph.resolve(systemName: "square.split.2x2", domain: .place) == .shelf)
        #expect(InventoryGlyph.resolve(systemName: "gearshape", domain: .item) == .gear)
        #expect(InventoryGlyph.resolve(systemName: "plus", domain: .location) == nil)
    }

    @Test func everyStableCatalogIDHasAnAuthoredSubject() {
        #expect(LocationIconCatalog.options.count == 28)
        #expect(PlaceIconCatalog.options.count == 9)
        #expect(ItemIconCatalog.options.count == 31)
        for option in LocationIconCatalog.options {
            #expect(LocationIconCatalog.option(for: option.id) == option)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .location) != nil)
        }
        for option in ItemIconCatalog.options {
            #expect(ItemIconCatalog.option(for: option.id) == option)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .item) != nil)
        }
        for option in PlaceIconCatalog.options {
            #expect(PlaceIconCatalog.option(for: option.id)?.id == option.id)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .place) != nil)
        }
    }

    @Test func unknownAndMissingContentUseAuthoredFallbacks() {
        #expect(InventoryGlyph.content(systemName: "unrecognized-content", domain: .location) == .locationMarker)
        #expect(InventoryGlyph.content(systemName: "unrecognized-content", domain: .place) == .box)
        #expect(InventoryGlyph.content(systemName: "unrecognized-content", domain: .item) == .box)
        #expect(InventoryGlyph.content(systemName: LocationIconCatalog.symbolName(for: "unknown-saved-id"), domain: .location) == .locationMarker)
        #expect(InventoryGlyph.content(systemName: PlaceIconCatalog.symbolName(for: "unknown-saved-id"), domain: .place) == .box)
        #expect(InventoryGlyph.content(systemName: ItemIconCatalog.symbolName(for: "unknown-saved-id"), domain: .item) == .box)
        #expect(InventoryGlyph.content(systemName: "mappin.slash", domain: .location) == .missingLocationMarker)
    }

    @Test func metadataAliasesRetainTheirContentMeaning() {
        let aliases: [(String, InventoryGlyph)] = [
            ("mappin.and.ellipse", .locationMarker), ("mappin.circle", .locationMarker),
            ("mappin.slash", .missingLocationMarker), ("location", .locationArrow),
            ("map", .map), ("tag", .tag), ("number", .quantity),
            ("note.text", .notes), ("checkmark.seal", .condition),
            ("clock", .clock), ("clock.arrow.circlepath", .clock),
            ("shippingbox.circle", .box)
        ]
        for (symbol, expected) in aliases {
            #expect(InventoryGlyph.resolve(systemName: symbol, domain: .item) == expected)
        }
    }

    @Test func visualStateIsIndependentOfSizeAndSelectionTakesPrecedence() {
        #expect(InventoryGlyph.Variant.resolve(identity: false, isSelected: false) == .outline)
        #expect(InventoryGlyph.Variant.resolve(identity: true, isSelected: false) == .material)
        #expect(InventoryGlyph.Variant.resolve(identity: false, isSelected: true) == .selected)
        #expect(InventoryGlyph.Variant.resolve(identity: true, isSelected: true) == .selected)
        for glyph in InventoryGlyph.allCases {
            #expect(Set(InventoryGlyph.Variant.allCases.map { glyph.assetName(for: $0) }).count == 3)
        }
    }

    @Test func allContentDrawingsAndStatesAreBundled() {
        for glyph in InventoryGlyph.allCases {
            for variant in InventoryGlyph.Variant.allCases {
                let name = glyph.assetName(for: variant)
                guard let data = NSDataAsset(name: name)?.data else {
                    Issue.record("Missing content artwork: \(name)")
                    continue
                }
                let source = CGImageSourceCreateWithData(data as CFData, nil)
                #expect(source != nil, "Invalid content PNG: \(name)")
                if let source {
                    #expect(CGImageSourceGetType(source) as String? == "public.png")
                }
            }
        }
        #expect(NSDataAsset(name: "InventoryGlyphLayout") != nil)
    }
}
