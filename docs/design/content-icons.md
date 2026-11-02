# Content Icon Family

`InventoryGlyphArtwork.swift` contains the editable SwiftUI vector drawings. `InventoryGlyph.swift` resolves compatible content symbols by domain without changing saved icon IDs, catalog ordering, category values or persistence. Shared icon and identity primitives render the authored drawing when covered and retain the existing SF Symbol otherwise. System actions continue to use SF Symbols.

Compact drawings use a 24 pt grid with a 1.85 pt rounded stroke. Identity drawings have a lighter 1.15 pt construction stroke, adjusted silhouettes, proportions and detail, and restrained two-plane tonal fills. Cabinet doors, the low notched drawer and open-top box remain distinct. Color comes from the owning Location, Storage Place or Item role; it is not fixed to an artwork.

## Current Catalog Coverage

| Catalog | Authored content drawing | Compatible SF Symbol fallback |
| --- | --- | --- |
| Location (28 IDs) | `room` → organizer, `kitchen` → kitchen, `box` → box, `cabinet` → cabinet, `office` → office, `bedroom` → bedroom, `closet` → cabinet, `wardrobe` → cabinet | `home`, `entryway`, `living-room`, `tv-area`, `lamp-area`, `coffee-station`, `refrigerator`, `archive`, `tray`, `garage`, `tools`, `workbench`, `files`, `books`, `bathroom`, `laundry`, `utility-sink`, `balcony`, `bike-storage`, `shed` |
| Storage Place (9 IDs) | `box` → box, `cabinet` → cabinet, `drawer` → drawer, `shelf` → shelf | `archive`, `tray`, `folder`, `hanger`, `basket` |
| Item (31 IDs) | `toolkit` → tools, `cable` → cable, `battery` → battery, `box` → box, `key` → keys | `screwdriver`, `hammer`, `gear`, `power-plug`, `display`, `desktop`, `laptop`, `phone`, `headphones`, `archive`, `tray`, `folder`, `document`, `clothing`, `bag`, `glasses`, `wallet`, `kitchen`, `cup`, `drop`, `sparkles`, `leaf`, `first-aid`, `bandage`, `pills`, `stethoscope` |

The family contains kitchen, office, bedroom, cabinet, drawer, box, shelf, organizer, cable, keys, battery and tools. Coverage is intentionally listed separately from the complete catalog: unsupported authored cases remain recognizable native symbols, not empty assets. An unknown Location ID retains the existing map-pin fallback. Unknown Item and Storage Place IDs retain the existing box fallback, which the content renderer draws as the authored box. No IDs are added or migrated.

The resolver distinguishes a Location's office from an Item's desktop computer, and a Location's closet from a Storage Place's hanger. Neutral actions and non-content palette roles do not enter the authored resolver. Shared labels, accessibility hiding, frames and Dynamic Type sizing remain owned by their existing wrappers.

When editing, inspect the full family at 24/32 pt and identity drawings at 48/64 pt in Light and Dark. Compare the [iconography reference](references/design-code-v1/boards/01-foundations-icons.png), then run the application and verify the changed content and picker surfaces. Keep one-off contact sheets and screenshots outside the source tree.
