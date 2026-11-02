# Visual Design

Status: Active current-state design guide

Home Stuff Inventory uses a calm, native, location-first SwiftUI presentation. This guide records the visual system implemented in the current source. It does not establish an App Store release or completed runtime validation. Current source and tests own implemented behavior, [`AGENTS.md`](../../AGENTS.md) owns repository guardrails, and an explicitly approved task owns change scope.

The [earlier density refinement](soft-cabinet-refinement.md) retains functional and quick-capture guardrails. This guide owns the current visual direction; its adaptive palette, geometry and materials supersede that document’s former visual freeze.

Current source and tests establish implemented behavior. Versioned references illustrate the accepted visual specification; neither a guide nor a reference image is runtime test evidence.

## Product And Information Hierarchy

The interface helps answer “Where did I put this thing?” and keeps the visible relationship `Location → Storage Place → Item`.

Present information in this order:

1. Item name — the thing the user wants to find.
2. Location and Storage Place — where it is, with Storage Place as the exact answer.
3. Category and Quantity — scanning and inventory context.
4. Condition, Notes, Tags, and dates — supporting detail.

Locations remains a first-class browse surface. Color reinforces the three domains, but geometry, icons, labels, composition, and reading order must preserve the same meaning without color.

## Semantics And Color Accents

Feature composition declares product meaning through `InventoryDesign.ContentRole`. `InventoryDesign` centrally maps that semantic role to an existing adaptive palette accent; feature views do not choose a coincidentally similar asset or palette alias when a content role exists.

| Semantic role | Identity accent | Surface treatment |
| --- | --- | --- |
| Item | Blue `InventorySecondaryAccent` | Opaque neutral content surface; blue identity accents |
| Location | Teal `InventoryStorageAccent` | Teal identity and relationship accents; `InventoryLocationAtmosphere` is reserved for the Location background |
| Storage Place | Plum `InventoryPlaceAccent` | Plum identity, relationship and compact badge accents on opaque neutral content surfaces |
| Primary action | Indigo `InventoryPrimaryAction` | Neutral actions, default native Form controls and editor focus |
| Context | Amber `InventoryContextHighlight` | Context emphasis rather than an Item identity |
| Brand text | Terracotta `InventoryBrandText` | Brand text; illustration fills remain in the icon artwork |

`InventoryDesign.Appearance` is the asset-backed adaptive-color layer. The existing color sets supply Light, Dark and both Increase Contrast variants; their values are owned by the assets, not by feature views or sampled illustration pixels. `AccentRole` describes palette treatments such as storage, Storage Place, primary action, secondary, context, muted, and tag colors. It does not stand in for Item, Location, or Storage Place meaning in feature composition.

Text roles remain independent from domain accents:

- screen, entity, section, and row titles use native semantic type and primary foregrounds;
- values remain primary and supporting text or metadata remains secondary;
- a short field label, icon, stroke, or low-opacity tint may use its owning domain accent;
- primary actions, destructive actions, Recent/context emphasis, and tags retain their own roles;
- no individual element combines multiple domain accents, and color never carries required meaning alone.

Neutral primary Add, Create, Save, Edit, and Retry actions use the adaptive Brand Indigo `InventoryPrimaryAction` role. Terracotta is a brand detail, not an action semantic. Actions use `inventoryPrimaryActionTint()` (or the empty-state primary-action wrapper that delegates to it), so native toolbars, Form rows, and prominent buttons retain their own system geometry. Location, Storage Place, Item, and context identities retain their established mappings; destructive actions retain system red.

Do not add per-record colors, category palettes, raw light/dark pairs, or a parallel theme/token system. Change an adaptive asset or semantic mapping only through a focused task with light, dark, Increased Contrast, and regression evidence.

## Surfaces, Depth, And Liquid Glass

- Keep native navigation, lists, forms, sheets, toolbars, menus, controls, SF Symbols, semantic colors, system typography, and platform spacing.
- Use native iOS Liquid Glass for system chrome and controls. Shared textual hero cards use the same opaque content base as other dense surfaces.
- Keep rows, Item cards, property cards, Notes, Tags, form fields, warnings, destructive states, and other dense text on stable readable content surfaces.
- Reuse the shared card, hero, row, badge, icon, form, empty-state, and glass primitives under `Views/Shared/`.
- Keep shared material and accessibility handling centralized in `InventoryGlassSurfaces.swift`; dense surfaces remain opaque in every transparency setting. Do not copy recipes into feature views.
- Avoid custom blurs, shaders, fake reflections, glow, colored shadows, decorative gradients, stacked transparency, and animation-heavy atmosphere unless a task explicitly approves them.

## Implemented Screen Composition

- Inventory uses compact individual Item cards: name, Location and exact Storage Place, then category and quantity. Long storage context uses a native stacked fallback. Search retains its richer result rows, broad matching, filters and query state.
- Locations overview uses vertical Location cards with neutral primary text, a teal Location glyph and one compact plum summary: Place count, up to two ranked names and the existing overflow count. Each card remains a single navigation target.
- Item Detail presents Item identity, the “Where is it?” answer, quantity/condition, Notes, bounded expandable Tags, labeled dates, history and destructive actions. Exact Storage Place uses the semibold field-value role; values remain neutral.
- Location Detail is ordered Location hero → Recent Items / All Items → Storage Places. The teal atmosphere stays behind opaque readable content.
- Recent Items keeps full-width rows, a maximum of three visible Items, existing ranking, overflow and destinations. Item glyphs are blue; accessibility rows place the glyph above the full-width title.
- Storage Place Detail uses the neutral grouped background, plum identity, the full Location/nested-Place path, child Places and scoped Items. Existing direct/all-contained counts and contextual row behavior remain intact.
- Add/Edit Item remains a native Form sheet: Name → Location/Storage Place → optional properties → Tags/Notes. Name is the only required value; missing storage stays neutral. Native focus, pickers, Save/Cancel, validation and unsaved-change confirmation remain in place, without the root Tab Bar in the sheet.
- Settings remains a native sectional list with management, history and data-transfer flows. Conditional controls retain their existing availability. Managed data rows use compact glyphs and row titles, with full-width identity at accessibility sizes.
- Locations remains the initial root tab, followed by Inventory and Settings, with a separate native Search role and its existing activation and placement. Preserve these navigation boundaries unless a focused approved task changes them.

Shared cards use 16 pt padding and 20 pt corners; compact rows and property cards use 12 pt padding and 14 pt corners. Location Detail separates its major sections by 24 pt, while row and grid gaps remain 8 and 12 pt. Identity plates use 24 pt corners, compact glyphs use a 32 pt frame, and identity glyphs use 40 pt; the Location overview uses a 36 pt glyph in a 60 pt frame. Detail content is bounded to 520 pt. These are default-size metrics, with existing Dynamic Type scaling. Native semantic text roles and content-driven height preserve hierarchy. Empty-state cards center their explanation and native action; callers declare the meaningful icon accent. Tags can wrap at accessibility text sizes. Prominent empty-state actions use the adaptive grouped-background color for their inverse label on the indigo fill.

The shared text roles use native styles: largeTitle bold for screen titles, title2 semibold for entity titles, headline for section/row titles and field values, caption semibold for field labels, subheadline medium for supporting text, and caption for metadata. Exact values and role mappings remain in `InventoryDesign`.

## Accessibility And Adaptation

- Preserve minimum 44×44 pt interactive targets, full-card hit regions, native control traits, and predictable VoiceOver order.
- Use native Dynamic Type styles; allow long English and Ukrainian content to wrap and reflow without fixed-height clipping.
- Keep required distinctions visible with Differentiate Without Color, Reduce Transparency, Increase Contrast, and Reduce Motion.
- Verify changed surfaces in light and dark appearances, at 320 pt and the iPhone 17 reference width, and at default and accessibility Dynamic Type.
- Compact Item, Recent Item, storage-answer and managed-value layouts move decorative glyphs above primary text at accessibility sizes where a side column would compress the answer. Native controls retain platform metrics.
- Validate behavior in the running app and focused tests; static mockups are not rendering evidence. Record actual system settings separately from QA overrides. A 320 pt content harness is not evidence of a 320 pt device or native chrome.
- Calculated opaque color-pair contrast does not certify live glass. VoiceOver label/order spot-checks do not establish a complete auditory audit. Keep unavailable checks distinct from executed results.

## Ownership And Change Boundary

`InventoryPresentation/InventoryDesign.swift` owns adaptive appearance assets, semantic-to-accent mapping, text roles, shared dimensions, opacity, depth, and glass constants. `Views/Shared/` owns reusable visual structure and modifiers. Feature views own screen composition and pass semantic intent into those shared owners.

Prefer the smallest existing abstraction. A new reusable view is for repeated structure, a modifier is for repeated decoration or behavior, a constant is for intentionally coordinated values, and one-off composition stays local. A visual approval does not authorize navigation, persistence, localization, privacy, Search, Tab Bar, or unrelated feature changes.

## App Icon

The [production app-icon guide](app-icon.md) documents the editable four-layer cabinet master, native appearances, and matching opaque fallback assets. Its frontal roof, mint body, and two centered drawers follow the accepted composition reference.

## Versioned Visual Reference

[Design Code Reference v1](references/design-code-v1/README.md) preserves the accepted app-icon composition, visual handbook, token specification and component/screen boards. Its files and publication-time proposal status remain unchanged. The current source implements the visual system described here; that original status is not a current implementation report. Within the bundle, PDF tables and JSON specify exact parameters and boards illustrate composition. Native navigation, behavior and accessibility remain governed by current source, tests and repository instructions.

The [content icon family](content-icons.md) documents the editable vector source, optical drawings and catalog fallback coverage.
