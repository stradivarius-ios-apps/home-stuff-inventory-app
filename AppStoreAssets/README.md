# App Store Assets

This folder holds release-preparation assets for App Store Connect. These files are not app runtime resources and should stay outside the app target bundle.

## Release Branding

Current App Store branding:

- App Store name: `Home Stuff Inventory`.
- On-device display name: `Home Stuff`.
- App icon asset: `Inventory-app`.
- App category: `public.app-category.productivity`.
- Latest tagged release: `v1.1.4`; current committed marketing version/build:
  `1.1.4 (1)`. The current `main` is newer than that tag. Deployment should normally
  leave workflow `version` and `build_number` blank so CI uses the committed marketing
  version and resolves the next upload build number after a higher release version is prepared.

The `Inventory-app` asset set is accepted for the current release. It includes default, dark, and tinted iOS icon variants, each as a 1024 x 1024 PNG without alpha transparency. The icon reads as a personal household inventory app and does not introduce warehouse, retail, insurance, account, sync, analytics, or cloud branding.

`Home Stuff` is accepted as the on-device display name. The shorter display name keeps the Home Screen label compact while the App Store listing, screenshot captions, privacy policy, and support page continue to use `Home Stuff Inventory`.

## Canonical Release Screenshot Workflow

`Release App Store Screenshots` is the public, hosted, non-signing validation and
diagnostic lane for an exact release ref. It uses an iPhone 14 Plus simulator on iOS
26.5 with light appearance and a fixed
9:41 status bar. The canonical contract is `1284 x 2778` portrait PNG for Apple's
6.5-inch iPhone slot, in this order:

1. `01-item-detail.png`
2. `02-locations-overview.png`
3. `03-location-detail.png`
4. `04-place-detail.png`
5. `05-search-answer.png`
6. `06-add-item-context.png`

Canonical output uses source locales `en` and `uk`; the manifest maps them
to App Store locales `en-GB` and `uk`. Missing, duplicate, unexpected/stale, mis-sized,
or misordered inputs fail validation. Successful runs do not upload screenshot
artifacts and generated screenshots are never committed automatically. When a capture
or publication fails, diagnostics may be retained as a best-effort artifact for three
days when GitHub artifact storage is available.

Apple's current specification allows 1284 x 2778 portrait screenshots for the 6.5-inch
iPhone slot and permits one to ten screenshots per localization:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications

## Screenshot Plan

Recommended upload order:

1. Item detail - Shows the exact storage answer, category, quantity, and condition for the USB-C display adapter.
2. Locations overview - Communicates the Location-first home storage map.
3. Location detail - Shows Home Office, its three Recent Items, and its Places.
4. Place detail - Shows Top desk drawer, its four Items, and the electronics warranty folder.
5. Search answer - Shows an `HDMI` name match, a tag match, and the exact Location and Place for both results.
6. Add item context - Shows `USB hub` with Location and Place prefilled from that scoped Place.

Optional seventh screenshot:

- Settings/Data or list administration, only if the current or next release listing needs to show shipped readable export, backup, restore, or reusable-value management. Keep captions explicit about user-initiated local files and do not imply arbitrary import or cloud sync.

## Capture Notes

- The release suite uses the dedicated localized DEBUG App Store fixture from #549, not `InventorySampleData`.
- Screenshot 01 may show the authentic Delete Item action. Screenshot 03 shows all three Recent Items and the Places section; screenshot 04 shows the electronics warranty folder; screenshot 05 uses `HDMI`, shows both results and the matched-tag badge, and dismisses the keyboard. English and Ukrainian user-owned demo text is localized.
- Screenshot 06 types `USB hub`, dismisses the keyboard, and keeps the prefilled Home Office / Top desk drawer context with Save enabled without saving.
- Do not crop, pad, resize, or otherwise alter screenshots to hide implemented UI.
- Do not fabricate screenshots or use mockups that imply unavailable features.

## Recapture

Dispatch `Release App Store Screenshots` with the exact release branch, tag, or full
commit SHA to validate or diagnose capture on GitHub-hosted infrastructure. This
workflow does not sign an app, use release credentials, or publish to App Store
Connect. Do not copy generated files into this repository.

## Final Review Checklist

- Confirm every screenshot is from the current app build and real UI.
- Confirm visible UI uses `Place`, not `Container`.
- Confirm no screenshot implies cloud sync, accounts, sharing, arbitrary file import, photos, barcode scanning, AI, analytics, ads, or tracking. Readable export, complete backup, and compatible restore may be shown only through their implemented Settings UI.
- Confirm captions match implemented behavior only.
- Confirm privacy statements match `docs/privacy/app-store-privacy-disclosures.md` and the public pages in `docs/privacy/public-pages.md`.
- Confirm naming, app icon, display name, and release branding do not conflict with the name/subtitle/captions in `AppStoreMetadata.md`.

## Public Validation And Private Publication Boundary

This public repository owns the screenshot specification, capture fixtures, hosted
non-signing capture workflow, and local validators. It does not own App Store Connect
credentials or credentialed audit/publication automation. Those operations remain a
maintainer-only responsibility of the separate private release control plane; its
operational details are intentionally outside this repository.

Local contract validation:

```sh
ruby .github/scripts/run_public_automation_checks.rb
ruby .github/scripts/validate_app_store_metadata.rb fastlane/metadata
```

Before a maintainer authorizes publication, review the exact tagged public source,
validate both `en-GB` and `uk` metadata, and confirm the ordered six-image sets produced
by the hosted capture workflow. Publication, App Store verification, and recovery are
performed only through the private release control plane.
