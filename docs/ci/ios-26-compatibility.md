# iOS 26.0 Compatibility Gate

Status: Release gate for every release that supports iOS 26.

Home Stuff Inventory supports iOS 26 starting at **26.0**. A newer SDK or a
26.x simulator must not raise the effective product minimum. The project keeps
its broader iOS deployment target, so Swift's availability checking rejects
unguarded APIs newer than that target; iOS 26-only native behavior must also
remain guarded at `iOS 26.0` with a fallback where it is not available.

## Required evidence

Record evidence against the exact release-candidate SHA outside this repository's
tracked source. Keep these three kinds of evidence distinct:

1. **Compile-time SDK compatibility.** Run the static gate and the ordinary app
   build. The static gate rejects deployment targets or `#available`/`@available`
   checks that name iOS 26.1 or later, and asserts the known native Search and
   Liquid Glass call sites retain 26.0 guards.
2. **Runtime availability.** Run the focused smoke suite on the earliest
   installed iOS 26 runtime. If iOS 26.0 is installed, it is mandatory; do not
   substitute a later 26.x runtime while claiming 26.0 smoke evidence.
3. **Simulator or device smoke evidence.** State the exact runtime and device,
   result bundle, locale, appearance, Dynamic Type, and VoiceOver result. A
   missing 26.0 runtime is an unavailable-evidence condition, not a pass.

```sh
ruby .github/scripts/verify_ios_26_compatibility.rb

xcodebuild build \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,id=<iOS-26.0-simulator-UDID>" \
  -configuration Debug
```

## iOS 26.0 smoke suite

Use an iOS 26.0 device selected from `xcrun simctl list devices available`.
Run the commands below without an entitlement or StoreKit activation. Together,
they cover launch, native tab/search presentation, Locations, Location Detail,
Recent Items, Storage Places, Inventory and global Search, Item add/edit/delete
and movement, Settings and Free portability entry points, Ukrainian, and maximum
Dynamic Type. Repeat the representative navigation checks in light and dark
appearance, and with VoiceOver enabled.

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,id=<iOS-26.0-simulator-UDID>" \
  -configuration Debug \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateBrowseAndPortabilityWithoutEntitlement \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testMaximumDynamicTypeNavigatesLocationItemDetailAndPicker \
  -only-testing:HomeStuffInventoryAppUITests/InventorySettingsUITests/testPlaceDirectoryIsLocalizedInUkrainianAndLeavesLocationCategorySemanticsUntouched
```

The hosted CI runtime is a current development baseline, not a statement of the
minimum supported iOS 26 point release. It cannot replace this release gate until
it offers iOS 26.0.
