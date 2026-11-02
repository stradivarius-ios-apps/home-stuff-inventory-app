# App Icon

The editable production master is [`Inventory-app.icon`](../../HomeStuffInventoryApp/Resources/Inventory-app.icon/). Its four named SVG layers are the mint cabinet, terracotta roof, amber drawer, and wider blue drawer. The drawers share a centered axis and contain bounded recessed notches. The artwork uses a 1024 × 1024 canvas; the platform supplies the outer mask.

Open the bundle in Icon Composer to edit the vector layers, native material settings, background, and appearance previews. Keep the four source layers aligned at their existing canvas coordinates. The Xcode resource phase includes the document and keeps `Inventory-app` as the app-icon name.

The native document supplies Default, Dark, Tinted Light/Dark and Clear Light/Dark renditions. Apple’s generation 26 renderer has broader colored highlights; generation 27 uses thinner contours. Compare both generations in Icon Composer when changing material settings. The layer composition and semantic artwork colors remain the same.

The [`Inventory-app.appiconset`](../../HomeStuffInventoryApp/Resources/Assets.xcassets/Inventory-app.appiconset/) retains opaque 1024 px Default, Dark and monochrome Tinted resources for earlier systems. They are derived from the same master through the native generation 26 renderer, with an opaque background for the asset-catalog files. Do not restore a different compartment arrangement in these fallback resources.

For a native preview, use Icon Composer’s export controls or its bundled `ictool` command with `--platform iOS`, the desired `--rendition`, `--width`, `--height`, `--scale 1`, and `--design-generation 26` or `27`. Check all six appearances at 32, 60 and 1024 px, then verify the built icon on the simulator Home Screen and in Settings. Keep diagnostic images outside the source tree.

The [versioned composition reference](references/design-code-v1/accepted-app-icon.png) remains unchanged. Production material rendering comes from the editable master and the system renderer. These resources do not imply an App Store upload or release.
