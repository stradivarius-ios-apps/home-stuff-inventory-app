# Content Icon Family

All 68 Location, Storage Place and Item catalog IDs resolve to authored content artwork through `InventoryGlyph.swift`. The family covers 62 subjects, including shared drawings and metadata such as maps, tags, quantity, condition, notes and history. The resolver preserves the saved IDs and their domain meanings. An unknown Location uses the authored location marker, while unknown Storage Places and Items use the authored box. Native search, navigation and action symbols retain their platform roles.

## Artwork and states

| State | Artwork | Use |
| --- | --- | --- |
| Outline | Flat contours and open interiors | Compact rows and inline metadata |
| Material | Restrained tinted planes | Location, Storage Place and Item identity |
| Selected | Filled shapes with deliberate openings | Selected options in icon and value pickers |

Each subject has three separately authored transparent PNGs in `Assets.xcassets/ContentGlyphs`. Selection takes precedence over identity when both apply. The semantic role determines the adaptive color in Light, Dark and both Increase Contrast variants. `InventoryGlyphArtwork.swift` tints outline and selected artwork as masks and retains the tonal separation in material artwork. The Storage Place picker resolves its adaptive tint before passing the drawings to the native menu.

Compact drawings preserve the subject silhouette and meaningful details. Evaluate optical weight and the smallest gaps at the actual display size. Narrower lines and gaps can preserve recognizable detail in dense compositions. Cabinet doors, the low notched drawer and the open-top box have distinct silhouettes.

## Updating the family

Create each state in ImageGen and retain the original transparent PNG bytes. Use the shared layout metadata to center the visible drawing within its frame. The renderer decodes thumbnails at display resolution. Shared wrappers own size, labels, accessibility and Dynamic Type.

Compare the [iconography reference](references/design-code-v1/boards/01-foundations-icons.png) with the family at 24/32 pt, material artwork at 48/64 pt, and smaller metadata in context. Inspect Light, Dark, and both Increase Contrast variants. Run the app to check compact rows, identity surfaces and picker transitions. Run `InventoryGlyphTests` to verify catalog resolution, fallbacks, state selection and the bundled artwork. Store one-off contact sheets and simulator captures outside the source tree.
