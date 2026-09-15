# iOS 27 Compatibility Gate

Status: Release gate for every release validated with iOS 27.

This gate confirms that the release candidate builds and its critical native
SwiftUI flows remain usable on iOS 27. It does not change the product minimum
deployment target or replace the separate iOS 26.0 compatibility gate. Any
iOS 27-only availability handling must be narrow, tied to a demonstrated
platform regression, and retain the existing iOS 18 and iOS 26 behavior.

## Required evidence

Record results against the exact release-candidate SHA outside tracked source.
The runtime, device model, result bundles, locale, appearance, Dynamic Type,
and accessibility outcomes are evidence; an installed runtime alone is not a
passing result.

1. **Toolchain, SDK, and runtime.** Use Xcode 27 or later with an iOS
   Simulator 27 SDK and the exact iOS 27.0 runtime. The static command below
   rejects an older Xcode or SDK and an unavailable 27.0 runtime.
2. **Build and smoke.** Run the focused smoke suite on an iOS 27.0 simulator.
   Do not substitute a later runtime while claiming iOS 27.0 evidence.
3. **Existing-data launch.** Start from a current production-compatible store,
   or restore the current production-compatible backup before relaunching.
   Confirm existing Items, Locations, Storage Places, movement history, readable
   export, backup, restore, and recovery entry points remain available.
4. **Manual platform checks.** On the same candidate, check the native root
   TabView, Search activation/dismissal and return to tabs, NavigationStack,
   sheets, menus, Lists/ScrollViews, safe-area clearance, and system materials.
   Repeat representative flows in English and Ukrainian; light and dark
   appearance; a representative large Dynamic Type size; VoiceOver; Reduce
   Motion; Reduce Transparency; and Increase Contrast. State any unavailable
   physical-device evidence as unavailable, never as a pass.

```sh
ruby .github/scripts/verify_ios_27_compatibility.rb

xcodebuild build \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,id=<iOS-27.0-simulator-UDID>" \
  -configuration Debug \
  -resultBundlePath TestResults/iOS27Build.xcresult
```

## iOS 27.0 smoke suite

Select an iOS 27.0 device from `xcrun simctl list devices available`. Run
without an entitlement or StoreKit activation. The focused suites cover clean
launch, the Free launch path, Locations and Storage Place browsing, global
Search, Item creation and movement, Settings export/backup/restore entry
points, Ukrainian, and maximum Dynamic Type.

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,id=<iOS-27.0-simulator-UDID>" \
  -configuration Debug \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateBrowseAndPortabilityWithoutEntitlement \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testMaximumDynamicTypeNavigatesLocationItemDetailAndPicker \
  -only-testing:HomeStuffInventoryAppUITests/InventorySettingsUITests/testPlaceDirectoryIsLocalizedInUkrainianAndLeavesLocationCategorySemanticsUntouched \
  -resultBundlePath TestResults/iOS27Smoke.xcresult
```

Review the produced result bundles and capture any demonstrated regression
before changing source. Native system behavior is the baseline: do not add a
parallel iOS 27 navigation, tab, Search, or material implementation merely to
match an earlier OS appearance.
