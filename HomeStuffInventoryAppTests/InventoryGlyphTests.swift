import Testing
import UIKit
@testable import HomeStuffInventoryApp

struct InventoryGlyphTests {
    @Test func contentMappingsRetainTheirDomainMeaning() {
        #expect(InventoryGlyph.resolve(systemName: "desktopcomputer", domain: .location) == .office)
        #expect(InventoryGlyph.resolve(systemName: "desktopcomputer", domain: .item) == nil)
        #expect(InventoryGlyph.resolve(systemName: "cabinet.fill", domain: .place) == .drawer)
        #expect(InventoryGlyph.resolve(systemName: "cabinet", domain: .place) == .cabinet)
        #expect(InventoryGlyph.resolve(systemName: "shippingbox", domain: .place) == .box)
        #expect(InventoryGlyph.resolve(systemName: "square.split.2x2", domain: .place) == .shelf)
        #expect(InventoryGlyph.resolve(systemName: "gearshape", domain: .item) == nil)
        #expect(InventoryGlyph.resolve(systemName: "plus", domain: .location) == nil)
    }

    @Test func existingCatalogIDsAndUnknownFallbacksRemainRenderable() {
        for option in LocationIconCatalog.options {
            #expect(LocationIconCatalog.option(for: option.id) == option)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .location) != nil || UIImage(systemName: option.symbolName) != nil)
        }
        for option in ItemIconCatalog.options {
            #expect(ItemIconCatalog.option(for: option.id) == option)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .item) != nil || UIImage(systemName: option.symbolName) != nil)
        }
        for option in PlaceIconCatalog.options {
            #expect(PlaceIconCatalog.option(for: option.id)?.id == option.id)
            #expect(InventoryGlyph.resolve(systemName: option.symbolName, domain: .place) != nil || UIImage(systemName: option.symbolName) != nil)
        }
        #expect(UIImage(systemName: LocationIconCatalog.symbolName(for: "unknown-saved-id")) != nil)
        #expect(InventoryGlyph.resolve(systemName: PlaceIconCatalog.symbolName(for: "unknown-saved-id"), domain: .place) == .box)
        #expect(InventoryGlyph.resolve(systemName: ItemIconCatalog.symbolName(for: "unknown-saved-id"), domain: .item) == .box)
    }

    @Test func allTwelveDrawingsHaveAProductionMapping() {
        let symbols: [(String, InventoryGlyph.Domain)] = [
            ("fork.knife", .location), ("desktopcomputer", .location), ("bed.double", .location),
            ("cabinet", .place), ("cabinet.fill", .place), ("shippingbox", .place),
            ("square.split.2x2", .place), ("square.grid.2x2", .location),
            ("cable.connector", .item), ("key", .item), ("battery.100percent", .item),
            ("wrench.and.screwdriver", .item)
        ]
        #expect(Set(symbols.compactMap { InventoryGlyph.resolve(systemName: $0.0, domain: $0.1) }) == Set(InventoryGlyph.allCases))
    }
}
