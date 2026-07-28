# Soft Cabinet Refinement Contract

Status: Approved implementation contract

This document freezes the target for the SCU refinement. It translates the approved visual direction into implementation boundaries that can be verified in source, tests, and rendered SwiftUI. It is an incremental refinement of the shipped app, not a new design system or product redesign.

## Authority And Conflict Resolution

Use this order when requirements appear to conflict:

1. [`AGENTS.md`](../../AGENTS.md) owns repository and product guardrails.
2. Current source and tests own shipped Search, navigation, data, and persistence behavior.
3. [`InventoryDesign.swift`](../../HomeStuffInventoryApp/InventoryPresentation/InventoryDesign.swift) owns semantic colors, surfaces, typography, spacing, depth, and glass constants.
4. This contract owns only the approved SCU structural changes.
5. Issue-specific acceptance criteria may narrow an SCU task but may not expand it.
6. Static mockups and screenshots illustrate composition only. They are never authoritative for Search placement, system chrome, color values, or semantic color assignments.

If a visual mockup disagrees with current Search or `InventoryDesign`, ignore the mockup on that point. An agent must stop and report an unresolved contradiction instead of selecting a new interpretation.

## Product Outcome

Home Stuff Inventory remains a private, local-first household inventory that answers “Where did I put this thing?” through the visible hierarchy `Location → Place → Item`.

The SCU outcome is a calmer soft cabinet:

- more Locations and Items can be scanned without hiding storage context;
- repeated chrome is quieter, especially in dark appearance;
- exact Place remains the strongest retrieval answer;
- Notes are reachable before large tag collections;
- a new Item begins with Name and storage context before optional decoration;
- native iOS Search, navigation, and system behavior remain familiar and untouched.

The target is not maximum density. Readability, spatial meaning, Dynamic Type, and forgiving data entry remain more important than fitting a fixed number of rows on screen.

## Frozen Product And Navigation Contract

The following behavior is already correct and is outside the epic:

- [`RootView.swift`](../../HomeStuffInventoryApp/Views/RootView.swift) retains the existing root `TabView`, tab order, independent `NavigationStack` values, and the native Search role.
- On supported iOS versions, Search remains `Tab(role: .search)` with `.tabViewSearchActivation(.searchTabSelection)` and `.searchable(..., placement: .automatic)`.
- The Search field remains in its current native Tab Bar presentation. Do not move it into custom content, add a second field, wrap it in a card, or replace it with a toolbar search control.
- Search query, broad matching, filters, active-filter context, results, empty states, navigation, accessibility, and legacy-iOS fallback remain unchanged.
- Locations remains the initially selected root tab. Inventory and Settings retain their current root roles.
- No custom Tab Bar, navigation bar, search field, activation behavior, or tab-selection coordinator is authorized.

No SCU implementation issue should edit `RootView.swift` or a Search-specific view. If a shared component change would alter Search results, split the minimum presentation boundary so Search keeps its shipped appearance and behavior.

## Frozen Semantic Palette

Do not add, recalibrate, swap, alias, or repurpose colors in this epic. Do not infer domain meaning from a mockup color. Feature composition declares one of the current semantic roles and lets `InventoryDesign` resolve the shipped adaptive asset.

| Meaning | Canonical source | Approved use |
| --- | --- | --- |
| Item | `InventoryDesign.ContentRole.item` → `InventorySecondaryAccent` | Item identity glyphs, restrained Item surfaces, and existing Item semantic treatments |
| Location | `InventoryDesign.ContentRole.location` → `InventoryStorageAccent` | Location identity glyphs, short labels, and established Location relationships |
| Location atmosphere | `InventoryLocationAtmosphere` | Location-scoped background/surface atmosphere only |
| Place | `InventoryDesign.ContentRole.place` → `InventoryPlaceAccent` | Place identity, Place relationships, badges, and restrained Place semantic tint |
| Neutral primary action | `InventoryPrimaryAction` | Add, Create, Save, Edit, and Retry through the existing semantic tint helpers |
| Context | `InventoryContextHighlight` | Existing Recent/context emphasis only |
| Coral | Existing brand/icon assets | Brand or icon detail only; never a general action, Item, Location, or Place semantic |
| Destructive | System destructive role | Delete and destructive confirmations only |

Primary titles and values remain neutral. Supporting text and metadata remain secondary. Color supports meaning but does not replace labels, icons, geometry, or reading order.

The following are prohibited:

- changing color-set values or appearance variants;
- introducing a new color set, theme, category palette, or per-record color;
- showing an Item in Location green, a Location in Place lavender, or a Place in Item blue;
- using Brand Indigo as a domain identity or a domain accent as a neutral action tint;
- compensating for a visual concern by silently changing the shared palette.

Any future palette calibration requires a separate explicitly approved task with light, dark, Increase Contrast, and regression evidence.

## Shared Visual Rules

- Preserve the established compact, backgroundless identity headers.
- Keep content readable on stable semantic surfaces. Do not apply Liquid Glass to repeated rows, properties, Notes, Tags, form fields, warnings, or dense text.
- Reuse native navigation, scroll views, lists, forms, sheets, toolbars, menus, pickers, system typography, SF Symbols, and platform spacing.
- Reuse existing primitives under `Views/Shared/` before adding an abstraction. A new reusable view requires a second concrete consumer.
- Do not add fixed card heights. Content must reflow at 320 pt width and accessibility Dynamic Type sizes.
- Preserve 44×44 pt targets, full-row hit regions, native control traits, predictable VoiceOver order, and meaning without color.
- Keep English and Ukrainian together for every changed user-facing string or localization call site.

## Approved Screen Changes

### Locations Overview

Owner: [`LocationsListView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationsListView.swift) and [`LocationSummaryRowView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationSummaryRowView.swift).

Keep:

- one full-card navigation target per Location;
- Location icon, name, Item count, current ordering, add action, and empty state;
- existing Place-preview ranking from browse summaries;
- Location identity and surface semantics.

Change:

- replace the repeated divider plus standalone Places preview block with one compact summary line;
- show the localized Place count followed by no more than two ranked Place names;
- when more Places remain, append a localized `+N` continuation;
- reduce vertical chrome through composition and existing spacing values, never a fixed height.

Do not:

- alter Place ranking, Location ordering, navigation, summary data, or empty-state behavior;
- introduce a carousel, horizontally scrolling chips, manual ordering, or a new summary model unrelated to bounded presentation;
- change Location or Place colors.

### Location Detail Place Index

Owner: [`LocationPlacesListView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationPlacesListView.swift) and [`PlaceSummaryRowView.swift`](../../HomeStuffInventoryApp/Views/Locations/PlaceSummaryRowView.swift).

Keep:

- compact Location identity header and `InventoryLocationAtmosphere` background;
- Recent Items / All Items behavior, destinations, and ranking;
- Places section, current Place order, Place glyph, name, Item count, category context, disclosure, empty state, and Add Item action.

Change:

- remove `PlaceSpatialIndexMarker` and its vertical connector/dots;
- render Places as equal-priority native rows without visual sequence or route semantics.

Do not:

- add numbering, a timeline, a tree control, custom indentation, drag ordering, or another spatial-order metaphor;
- change Place management, recent-view behavior, or Location/Place semantic colors.

### Inventory Overview Rows

Owner: [`InventoryItemNavigationCard.swift`](../../HomeStuffInventoryApp/Views/Inventory/InventoryItemNavigationCard.swift), [`InventoryCompactItemCard.swift`](../../HomeStuffInventoryApp/Views/Inventory/InventoryCompactItemCard.swift), and [`ScopedInventoryItemsListView.swift`](../../HomeStuffInventoryApp/Views/Inventory/ScopedInventoryItemsListView.swift) where they route or render compact Inventory/scoped-list rows. [`InventoryItemRowView.swift`](../../HomeStuffInventoryApp/Views/Inventory/InventoryItemRowView.swift) is the Search-only row and remains a nonvisual regression boundary; it may change only for a minimal, proven separation that leaves Search output unchanged.

Keep:

- Item name first;
- Location → Place path immediately below, with exact Place visually stronger than Location;
- category and quantity context;
- Item glyph and `InventorySecondaryAccent`, Location icon/relationship and `InventoryStorageAccent`, and Place icon/relationship and `InventoryPlaceAccent`;
- navigation, filters, ordering, matching, actions, accessibility, and list state.

Change:

- retain `inventorySemanticSurface(.item)` and the current blue Item semantic tint;
- make repeated rows quieter only through composition and existing spacing, depth, and stroke behavior, without changing their semantic surface or color;
- reduce redundant outline/shadow emphasis only where the existing shared surface API and accessibility paths support it, while retaining the stronger current Increase Contrast treatment.

Do not:

- remove any displayed information;
- change rich Search result rows or the Search presentation;
- replace the Item surface with neutral, Location, Place, action, or context color treatment;
- create new neutral, border, dark-mode, or domain colors;
- apply a global card redesign to other features.

If Search and Inventory currently share implementation, separating their presentation is allowed only to keep Search unchanged. The split itself must not modify Search output.

### Item Detail

Owner: [`InventoryItemDetailView.swift`](../../HomeStuffInventoryApp/Views/Inventory/InventoryItemDetailView.swift), [`InventoryItemDetailSurfaces.swift`](../../HomeStuffInventoryApp/Views/Inventory/InventoryItemDetailSurfaces.swift), and [`InventoryItemDetailViewModel.swift`](../../HomeStuffInventoryApp/InventoryPresentation/InventoryItemDetailViewModel.swift).

Required reading order:

1. compact Item identity;
2. Where is it? with Location and exact Place;
3. properties;
4. Notes;
5. Tags;
6. labeled dates/secondary metadata;
7. destructive actions.

Keep:

- the compact identity header, Item identity glyph, and category context;
- exact Place as the strongest storage value;
- Location and Place semantic mappings;
- Notes edit sheet and persistence outcomes;
- delete confirmation, toolbar edit, recent-view recording, and navigation behavior.

Change:

- remove the raw last-updated timestamp from the compact identity header;
- present dates as clearly labeled, low-emphasis metadata near the bottom;
- move Notes before Tags;
- with more than three tags, show the first three in their existing deterministic order and a localized compact `+N` control;
- expand all tags inline on activation and provide an accessible collapse action.

Do not:

- add or change tag CRUD, tag ordering, notes persistence, metadata, colors, or animation systems;
- invent a replacement chip layout when the current tag layout can be bounded.

### Add/Edit Item

Owner: [`InventoryItemFormView.swift`](../../HomeStuffInventoryApp/Views/InventoryItemFormView.swift), focused children under `Views/Inventory/Form/`, and the existing form workflow/persistence owners.

Required section order:

1. Item — Name only;
2. Where is it? — Location, then Place;
3. Details — Category, Quantity, Condition, optional Item Icon last;
4. Context — Tags and Notes.

Keep:

- Name as the only required field;
- Location and Place strongly encouraged but optional;
- Place disabled until Location;
- delayed Name validation, discard protection, Location-change Place review, save/rollback outcomes, reusable selections, and all persistence behavior;
- native `Form`, `NavigationLink`, `Picker`, `Stepper`, sheets, alerts, and current semantic tints.

Change:

- when a new global or pre-scoped Add Item form is first presented, focus Name and show the keyboard when platform and accessibility focus permit;
- do not force focus for edit mode, picker returns, restored validation state, or a VoiceOver flow that has already established focus;
- move optional Item Icon from the first section to the last row of Details.

Do not:

- add required storage, a wizard, new fields, icon/category inference, a custom keyboard toolbar, picker redesign, or persistence changes.

## Explicitly Unchanged Screens And Assets

The epic does not modify:

- Search or root Tab Bar;
- Settings;
- Place Detail except where an already-shared compact Inventory row receives the approved SCU-04 treatment;
- App icon or App Store artwork;
- empty-state visual language outside named screens;
- semantic color assets or `InventoryDesign` mappings;
- backup/restore, list management, persistence models, ranking, matching, filters, and recent-view logic;
- product capabilities, permissions, privacy behavior, or release metadata.

## Delivery Boundaries And Dependencies

Freeze this contract before implementation. Inventory, Item Detail, and Item Form may then proceed independently. Keep the Location lane ordered: compact the Location overview before simplifying the Location Storage Place index when their shared primitives overlap. Integrated validation is last and may fix only contract regressions; a new idea requires a separate approved change.

### Integrated Validation

Owner: current source, tests, and this contract record the shipped facts. The former
integrated audit evidence is retained only in the private historical archive and is not
part of the clean public Git history. Integrated validation may not introduce a design
decision, expand implementation scope, or revise this contract to authorize a new
idea; any out-of-contract finding requires a separate issue.

Each implementation change remains focused and independently reviewable.

## Validation Matrix

Every implementation change validates its changed surface. Final integrated validation repeats the full matrix.

| Surface | Required states | Required regression proof |
| --- | --- | --- |
| Locations overview | 0/1/2/many Places, long EN/UK names, default and accessibility type, light/dark, 320 pt and iPhone 17 width | Ordering, navigation, add, empty state, Place ranking unchanged |
| Location detail | 0/1/many Places, Recent Items present/absent, EN/UK, light/dark, Increase Contrast, large type | All Items, recent destinations, Place order, add, atmosphere unchanged |
| Inventory | dense and sparse data, missing storage, multi-digit quantity, EN/UK, light/dark, Increase Contrast, large type | filters, navigation, matching, actions, Search screenshots unchanged |
| Item detail | 0/1/3/4/many tags, empty/long Notes, dates, missing storage, EN/UK, light/dark, large type | Notes save/rollback, delete, edit, recent-view behavior unchanged |
| Item form | new/edit, global/pre-scoped create, picker return, validation blur, dirty dismiss, Place review, save failure, EN/UK, light/dark, large type | Name-only save, no forced edit focus, persistence and rollback unchanged |
| Search and Tab Bar | current deterministic populated/empty/filter states | Existing UI/screenshot tests pass without approved visual or behavior changes |

For app changes, run focused deterministic tests, localization tests when strings or call sites change, `git diff --check`, and the baseline iPhone 17 simulator build. Use rendered SwiftUI or Simulator evidence; static mockups do not prove completion.

## Epic Exit Criteria

The epic can close only when:

- the approved density and hierarchy refinements are present without fixed-size regressions;
- exact Place remains the strongest retrieval answer;
- Notes precede bounded Tags and date metadata is clearly secondary;
- new Item capture starts with Name and storage before optional icon choice;
- Search and the root Tab Bar are demonstrably unchanged;
- no semantic color asset or domain assignment changed;
- EN/UK, light/dark, accessibility settings, focused tests, localization tests, and baseline build pass;
- the final evidence contains no unapproved redesign, feature, abstraction, or palette work.
