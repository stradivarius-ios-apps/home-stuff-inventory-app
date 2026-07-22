# App Store Metadata

> The version-localized source of truth has moved to `fastlane/metadata/en-GB`
> and `fastlane/metadata/uk`. This document retains app-name, category,
> screenshot-caption, and review guidance that the publishing lane deliberately
> does not manage.

Current App Store listing copy for the released local-first, Location-first app behavior.

## App Store Connect Copy

### Name

Home Stuff Inventory

### Subtitle

See `fastlane/metadata/en-GB/subtitle.txt` and the Ukrainian counterpart.

### Promotional Text

See the locale-specific `promotional_text.txt` files under `fastlane/metadata`.

### Description

See the locale-specific `description.txt` files under `fastlane/metadata`.

### Keywords

See the locale-specific `keywords.txt` files under `fastlane/metadata`.

### Category

Productivity.

### Support URL

See the locale-specific `support_url.txt` files under `fastlane/metadata`.

### Privacy Policy URL

See the locale-specific `privacy_url.txt` files under `fastlane/metadata`.

## Screenshot Captions

Use concise captions if App Store artwork adds text outside the raw screenshots. They are artwork direction only; the raw app screenshots do not render these headlines.

English:

1. Know exactly where every Item lives.
2. Turn your home into a storage map.
3. Browse Places and recent Items.
4. See everything stored in one Place.
5. Find the exact Place in seconds.
6. Add Items with Location and Place ready.

Ukrainian:

1. Одразу бачте, де лежить кожна річ.
2. Ваш дім як мапа зберігання.
3. Місця й нещодавні речі поруч.
4. Усе з цієї шухляди — в одному списку.
5. Знайдіть точне Місце за секунди.
6. Додавайте речі вже з готовим контекстом.

## Review Guardrails

- Use `Place`, not `Container`, in public-facing copy.
- Do not mention sync, accounts, sharing, arbitrary file import, photos, barcode scanning, AI, reminders, widgets, Shortcuts, Spotlight, QR labels, or cloud features. Readable export, complete manual backup, and compatible restore are shipped local Free workflows and may be described accurately.
- Do not describe the app as unfinished, experimental, review-only, or preview-only.
- Keep privacy copy consistent with the current privacy disclosure notes: no developer data collection, no tracking, no analytics, no ads, no backend service, and no cloud sync in the current release.
- Coordinate release documentation before changing the app name, display name, icon, subtitle, or screenshot caption direction.
