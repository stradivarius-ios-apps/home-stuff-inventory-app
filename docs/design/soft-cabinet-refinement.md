# Soft Cabinet Refinement Contract

Status: Historical density and functional guardrail

This document retains earlier density, retrieval and quick-capture decisions. The [current visual guide](README.md) owns implemented palette values, geometry, glyphs and materials and supersedes the former visual freeze below. The retained screen decisions describe existing behavior, not a new work queue or a restriction on explicitly approved visual changes.

## Authority And Conflict Resolution

[`AGENTS.md`](../../AGENTS.md) owns repository and product guardrails. Current source and tests own Search, navigation, data and persistence behavior. The [current visual guide](README.md), [`InventoryDesign.swift`](../../HomeStuffInventoryApp/InventoryPresentation/InventoryDesign.swift) and existing adaptive assets own the implemented visual system.

The [versioned visual reference](references/design-code-v1/README.md) remains an immutable comparison specification. Its PDF/JSON values take precedence over its rendered boards; painted controls do not replace native navigation or accessibility. This historical document cannot override the current guide with an older palette or surface rule.

## Product Outcome

Home Stuff Inventory remains a private, local-first household inventory that answers “Where did I put this thing?” through the visible hierarchy `Location → Place → Item`.

The retained density outcome is a calmer soft cabinet:

- more Locations and Items can be scanned without hiding storage context;
- repeated chrome is quieter, especially in dark appearance;
- exact Place remains the strongest retrieval answer;
- Notes are reachable before large tag collections;
- a new Item begins with Name and storage context before optional decoration;
- native iOS Search, navigation, and system behavior remain familiar and untouched.

The target is not maximum density. Readability, spatial meaning, Dynamic Type, and forgiving data entry remain more important than fitting a fixed number of rows on screen.

## Retained Product And Navigation Contract

The following behavior remains a regression boundary:

- [`RootView.swift`](../../HomeStuffInventoryApp/Views/RootView.swift) retains the existing root `TabView`, tab order, independent `NavigationStack` values, and the native Search role.
- On supported iOS versions, Search remains `Tab(role: .search)` with `.tabViewSearchActivation(.searchTabSelection)` and `.searchable(..., placement: .automatic)`.
- The Search field remains in its current native Tab Bar presentation. Do not move it into custom content, add a second field, wrap it in a card, or replace it with a toolbar search control.
- Search query, broad matching, filters, active-filter context, results, empty states, navigation, accessibility, and legacy-iOS fallback remain unchanged.
- Locations remains the initially selected root tab. Inventory and Settings retain their current root roles.
- No custom Tab Bar, navigation bar, search field, activation behavior, or tab-selection coordinator is authorized.

A density or content-style change does not authorize edits to `RootView.swift` or Search behavior. If a shared component change would alter Search results, split the minimum presentation boundary so Search keeps its shipped appearance and behavior.

## Semantic Role Guardrails

The earlier palette-value freeze is superseded by the current adaptive assets and [visual guide](README.md). The domain-to-role mapping remains stable: Item blue, Location teal and Storage Place plum; neutral actions are indigo, context is amber and brand detail is terracotta. Feature composition declares semantic meaning and lets `InventoryDesign` resolve its adaptive asset.

| Meaning | Canonical source | Approved use |
| --- | --- | --- |
| Item | `InventoryDesign.ContentRole.item` → `InventorySecondaryAccent` | Item identity glyphs, restrained Item surfaces, and existing Item semantic treatments |
| Location | `InventoryDesign.ContentRole.location` → `InventoryStorageAccent` | Location identity glyphs, short labels, and established Location relationships |
| Location atmosphere | `InventoryLocationAtmosphere` | Location-scoped background/surface atmosphere only |
| Place | `InventoryDesign.ContentRole.place` → `InventoryPlaceAccent` | Place identity, Place relationships, badges, and restrained Place semantic tint |
| Neutral primary action | `InventoryPrimaryAction` | Add, Create, Save, Edit, and Retry through the existing semantic tint helpers |
| Context | `InventoryContextHighlight` | Existing Recent/context emphasis only |
| Terracotta | Existing brand/icon assets | Brand or icon detail only; never a general action, Item, Location, or Place semantic |
| Destructive | System destructive role | Delete and destructive confirmations only |

Primary titles and values remain neutral. Supporting text and metadata remain secondary. Color supports meaning but does not replace labels, icons, geometry, or reading order.

The following are prohibited:

- introducing a new color set, theme, category palette, or per-record color;
- showing an Item in Location teal, a Location in Place plum, or a Place in Item blue;
- using Brand Indigo as a domain identity or a domain accent as a neutral action tint;
- compensating for a visual concern by silently changing the shared palette.

A palette calibration requires an explicitly approved task with light, dark, Increase Contrast, and regression evidence.

## Shared Visual Rules

- Preserve the established compact, backgroundless identity headers.
- Keep content readable on stable semantic surfaces. Do not apply Liquid Glass to repeated rows, properties, Notes, Tags, form fields, warnings, or dense text.
- Reuse native navigation, scroll views, lists, forms, sheets, toolbars, menus, pickers, system typography, SF Symbols, and platform spacing.
- Reuse existing primitives under `Views/Shared/` before adding an abstraction. A new reusable view requires a second concrete consumer.
- Do not add fixed card heights. Content must reflow at 320 pt width and accessibility Dynamic Type sizes.
- Preserve 44×44 pt targets, full-row hit regions, native control traits, predictable VoiceOver order, and meaning without color.
- Keep English and Ukrainian together for every changed user-facing string or localization call site.

## Retained Screen Decisions

### Locations Overview

Owner: [`LocationsListView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationsListView.swift) and [`LocationSummaryRowView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationSummaryRowView.swift).

Keep:

- one full-card navigation target per Location;
- Location icon, name, Item count, current ordering, add action, and empty state;
- existing Place-preview ranking from browse summaries;
- Location identity and surface semantics.

Retained refinement:

- replace the repeated divider plus standalone Places preview block with one compact summary line;
- show the localized Place count followed by no more than two ranked Place names;
- when more Places remain, append a localized `+N` continuation;
- reduce vertical chrome through composition and existing spacing values, never a fixed height.

Do not:

- alter Place ranking, Location ordering, navigation, summary data, or empty-state behavior;
- introduce a carousel, horizontally scrolling chips, manual ordering, or a new summary model unrelated to bounded presentation;
- repurpose Location or Storage Place semantic roles.

### Location Detail Place Index

Owner: [`LocationPlacesListView.swift`](../../HomeStuffInventoryApp/Views/Locations/LocationPlacesListView.swift) and [`PlaceSummaryRowView.swift`](../../HomeStuffInventoryApp/Views/Locations/PlaceSummaryRowView.swift).

Keep:

- compact Location identity header and `InventoryLocationAtmosphere` background;
- Recent Items / All Items behavior, destinations, and ranking;
- Places section, current Place order, Place glyph, name, Item count, category context, disclosure, empty state, and Add Item action.

Retained refinement:

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

Retained refinement:

- retain `inventorySemanticSurface(.item)` as the existing semantic owner; its current dense surface is opaque and neutral, with blue Item identity;
- keep exact storage context legible through existing spacing and adaptive layout;
- preserve the shared Increase Contrast treatment.

Do not:

- remove any displayed information;
- change rich Search result rows or the Search presentation;
- substitute another domain identity or an action/context role for the Item role;
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

Retained refinement:

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

Retained refinement:

- when a new global or pre-scoped Add Item form is first presented, focus Name and show the keyboard when platform and accessibility focus permit;
- do not force focus for edit mode, picker returns, restored validation state, or a VoiceOver flow that has already established focus;
- move optional Item Icon from the first section to the last row of Details.

Do not:

- add required storage, a wizard, new fields, icon/category inference, a custom keyboard toolbar, picker redesign, or persistence changes.

## Retained Functional Boundary

Visual refinement does not authorize changes to Search or the root Tab Bar, persisted data, backup/restore transactions, ranking, matching, filters, recent-view logic, feature availability, permissions, privacy or release metadata. Settings, Storage Place Detail, icon artwork and shared content surfaces follow the current visual guide; their former exclusion from the density refinement is not a current visual freeze.

Each change remains focused and independently reviewable. Current source and tests establish implementation; historical validation or a document alone does not establish runtime success.

## Validation Matrix

Every implementation change validates its changed surface. Integrated validation records the representative states actually exercised and their source identity.

| Surface | Required states | Required regression proof |
| --- | --- | --- |
| Locations overview | 0/1/2/many Places, long EN/UK names, default and accessibility type, light/dark, 320 pt and iPhone 17 width | Ordering, navigation, add, empty state, Place ranking unchanged |
| Location detail | 0/1/many Places, Recent Items present/absent, EN/UK, light/dark, Increase Contrast, large type | All Items, recent destinations, Place order, add, atmosphere unchanged |
| Inventory | dense and sparse data, missing storage, multi-digit quantity, EN/UK, light/dark, Increase Contrast, large type | filters, navigation, matching, actions, Search screenshots unchanged |
| Item detail | 0/1/3/4/many tags, empty/long Notes, dates, missing storage, EN/UK, light/dark, large type | Notes save/rollback, delete, edit, recent-view behavior unchanged |
| Item form | new/edit, global/pre-scoped create, picker return, validation blur, dirty dismiss, Place review, save failure, EN/UK, light/dark, large type | Name-only save, no forced edit focus, persistence and rollback unchanged |
| Search and Tab Bar | current deterministic populated/empty/filter states | Existing UI/screenshot tests pass without approved visual or behavior changes |

For app changes, run focused deterministic tests, localization tests when strings or call sites change, `git diff --check`, and the baseline iPhone 17 simulator build. Use rendered SwiftUI or Simulator evidence; static mockups do not prove completion.

## Retained Regression Checks

Validate that:

- the approved density and hierarchy refinements are present without fixed-size regressions;
- exact Place remains the strongest retrieval answer;
- Notes precede bounded Tags and date metadata is clearly secondary;
- new Item capture starts with Name and storage before optional icon choice;
- Search and the root Tab Bar are demonstrably unchanged;
- semantic domain assignments remain intact and current adaptive assets match the visual guide;
- EN/UK, light/dark, accessibility settings, focused tests, localization tests, and baseline build pass;
- evidence describes the actual source and settings without asserting a release or an unperformed check.
