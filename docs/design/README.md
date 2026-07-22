# Visual Design

Status: Active current-state design guide

Home Stuff Inventory uses a calm, native, location-first SwiftUI presentation. This guide records the durable shipped approach. Current source and tests own implemented behavior, [`AGENTS.md`](../../AGENTS.md) owns repository guardrails, and an explicitly approved task owns change scope.

The shipped [Soft Cabinet Refinement Contract](soft-cabinet-refinement.md) records the accepted density, hierarchy, and quick-capture boundaries. It explicitly freezes Search, the root Tab Bar, and the existing semantic palette assignments.

Former concepts, delivery maps, and audit evidence are retained only in the private historical archive and are not transferred in this repository's clean public Git history. They are not current implementation instructions.

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
| Item | Existing blue `InventorySecondaryAccent` | Blue semantic tint on Item surfaces; primary text remains neutral |
| Location | Existing green `InventoryStorageAccent` | Green identity accents; `InventoryLocationAtmosphere` is reserved for the Location surface/background tint |
| Storage Place | Existing lavender `InventoryPlaceAccent` | Lavender identity, relationship, badge, and restrained semantic-surface tint |

`InventoryDesign.Appearance` is the asset-backed adaptive-color layer. `AccentRole` describes palette treatments such as storage, Storage Place, primary action, secondary, context, muted, and tag colors. It does not stand in for Item, Location, or Storage Place meaning in feature composition.

Text roles remain independent from domain accents:

- screen, entity, section, and row titles use native semantic type and primary foregrounds;
- values remain primary and supporting text or metadata remains secondary;
- a short field label, icon, stroke, or low-opacity tint may use its owning domain accent;
- primary actions, destructive actions, Recent/context emphasis, and tags retain their own roles;
- no individual element combines multiple domain accents, and color never carries required meaning alone.

Neutral primary Add, Create, Save, Edit, and Retry actions use the adaptive Brand Indigo `InventoryPrimaryAction` role. Coral is an icon/brand detail, not an action semantic. Apply this tint only through `inventoryPrimaryActionTint()` (or the empty-state primary-action wrapper that delegates to it), so native toolbars, Form rows, and prominent buttons retain their own system geometry. Location, Storage Place, Item, and context identities retain their established mappings; destructive actions retain system red.

Do not add per-record colors, category palettes, raw light/dark pairs, or a parallel theme/token system. Change an adaptive asset or semantic mapping only through a focused task with light, dark, Increased Contrast, and regression evidence.

## Surfaces, Depth, And Liquid Glass

- Keep native navigation, lists, forms, sheets, toolbars, menus, controls, SF Symbols, semantic colors, system typography, and platform spacing.
- Use native iOS Liquid Glass selectively for system chrome, compact controls, and calm identity heroes. Identity heroes are not controls, so their glass remains non-interactive.
- Keep rows, Item cards, property cards, Notes, Tags, form fields, warnings, destructive states, and other dense text on stable readable content surfaces.
- Reuse the shared card, hero, row, badge, icon, form, empty-state, and glass primitives under `Views/Shared/`.
- Keep glass recipes and accessibility fallbacks centralized in `InventoryGlassSurfaces.swift`; do not copy them into feature views.
- Avoid custom blurs, shaders, fake reflections, glow, colored shadows, decorative gradients, stacked transparency, and animation-heavy atmosphere unless a task explicitly approves them.

## Shipped Screen Composition

- Inventory uses compact individual Item cards. Search retains its richer result rows and broad matching behavior.
- Locations overview uses rich vertical Location cards: neutral primary text, a split header with an unframed green Location symbol, and full-width lavender Storage Place previews.
- Item Detail presents Item identity first, then the Location and exact Storage Place answer, followed by supporting properties, tags, notes, and actions.
- Location Detail is ordered Location hero → Recent Items / All Items → Storage Places. The green atmosphere stays behind opaque readable content.
- Recent Items keeps its containerless section composition, maximum of three visible Items, existing overflow, destinations, and adaptive layouts.
- Storage Place Detail uses the neutral grouped screen background, lavender Storage Place identity, and a clearly labeled green parent-Location relationship.
- Add/Edit Item remains a forgiving native form. Name is the only required value; Location and Storage Place are strongly encouraged.
- Settings remains a native list. Preserve Search and the root system Tab Bar unless a focused approved task changes them.

## Accessibility And Adaptation

- Preserve minimum 44×44 pt interactive targets, full-card hit regions, native control traits, and predictable VoiceOver order.
- Use native Dynamic Type styles; allow long English and Ukrainian content to wrap and reflow without fixed-height clipping.
- Keep required distinctions visible with Differentiate Without Color, Reduce Transparency, Increase Contrast, and Reduce Motion.
- Verify changed surfaces in light and dark appearances, at 320 pt and the iPhone 17 reference width, and at default and accessibility Dynamic Type.
- Validate behavior in working SwiftUI and focused tests; static mockups are not rendering evidence.

## Ownership And Change Boundary

`InventoryPresentation/InventoryDesign.swift` owns adaptive appearance assets, semantic-to-accent mapping, text roles, shared dimensions, opacity, depth, and glass constants. `Views/Shared/` owns reusable visual structure and modifiers. Feature views own screen composition and pass semantic intent into those shared owners.

Prefer the smallest existing abstraction. A new reusable view is for repeated structure, a modifier is for repeated decoration or behavior, a constant is for intentionally coordinated values, and one-off composition stays local. A visual approval does not authorize navigation, persistence, localization, privacy, Search, Tab Bar, or unrelated feature changes.
