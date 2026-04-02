# Frontend Redesign — Design Spec

**Date:** 2026-04-01
**Status:** Approved

## Overview

A visual and UX overhaul of the BackyardGarden frontend. The current UI uses the default Phoenix boilerplate home page, a plain table for the seed library with limited filtering, and a sparse seed detail page. This redesign applies a Botanical & Lush design language, replaces the boilerplate home page with a proper landing page, adds full sort and filter to the seed library, makes the layout responsive (table on desktop, cards on mobile), and restructures the seed detail page into a two-column layout.

---

## Design Language

### Color Palette

| Role | Value | Usage |
|---|---|---|
| Primary dark | `#1a3a2a` | Nav gradient start, accents |
| Primary mid | `#2d6a4f` | Nav gradient end, buttons, growing guide accent border |
| Primary light | `#52b788` | Active nav underline, labels, section headers |
| Surface bg | `#f0fdf4` | Page background, table header, card hover |
| Surface white | `#ffffff` | Cards, table rows |
| Border | `#bbf7d0` | Card and table borders |
| Text primary | `#14532d` | Seed names, headings |
| Text secondary | `#6b7280` | Supporting metadata |
| Text body | `#374151` | Body copy |

### Type Badges (color-coded by seed type)

| Type | Text color | Background |
|---|---|---|
| Vegetable | `#16a34a` | `#dcfce7` |
| Herb | `#7c3aed` | `#ede9fe` |
| Flower | `#d97706` | `#fef3c7` |
| Berry | `#db2777` | `#fce7f3` |

### DaisyUI Theme

Update the existing `light` DaisyUI theme in `assets/css/app.css` to use botanical greens:
- `--color-primary`: `oklch(40% 0.118 160)` — botanical green (replaces Phoenix orange `oklch(70% 0.213 47.604)`)
- `--color-primary-content`: `oklch(97% 0.014 160)`
- `--color-base-100`: `oklch(98% 0.014 150)` — mint surface (approx `#f0fdf4`)
- `--color-base-content`: `oklch(22% 0.07 155)` — dark green text (approx `#14532d`)

---

## Navigation

**Component:** `Layouts.app/1` in `lib/backyard_garden_web/components/layouts.ex`

- Background: dark green gradient (`#1a3a2a → #2d6a4f`)
- Logo: 🌿 emoji + "BackyardGarden" in `#d8f3dc`, bold
- Nav links: "Seeds", "My Garden", "Calendar"
  - Active link: `#95d5b2` text + `#52b788` bottom border
  - Inactive links: `rgba(255,255,255,0.5)`
- Max width: `max-w-5xl`, horizontally centered

---

## Home Page (`/`)

**File:** `lib/backyard_garden_web/controllers/page_html/home.html.heex`

Replaces the Phoenix Framework boilerplate entirely.

### Content

**Hero section:**
- Eyebrow label: "Your Garden, Planned" in `#52b788`, uppercase, letter-spaced
- Headline: "Know what to plant, and when to plant it."
- Subtext: "Browse your seed library, track plantings, and get timely reminders — all in one place."
- CTA button: "Browse Seed Library →" linking to `/seeds`, styled in `#2d6a4f`

**Dashboard placeholder grid (2×2):**
Four cards with muted styling (reduced opacity) showing upcoming features:
- 🌱 Plant Now — "Coming in Phase 3"
- ☁️ Weather — "Coming in Phase 3"
- 📅 Upcoming — "Coming in Phase 3"
- ✓ Recently Planted — "Coming in Phase 2"

These placeholders will be replaced with live content as phases are implemented.

---

## Seed Library (`/seeds`)

**File:** `lib/backyard_garden_web/live/seeds/index_live.html.heex`
**LiveView:** `lib/backyard_garden_web/live/seeds/index_live.ex`

### Filter Bar

A white card (`rounded-xl`, `border border-[#bbf7d0]`) containing:
- Search input (existing `phx-debounce="300"`)
- Dropdowns for: Type, Brand, Cycle, Planting Method, Sun Requirement
- All filters wire to the existing `"filter"` LiveView event

The `Seeds.list_seeds/1` context function and `IndexLive` must be extended to support filtering by `planting_method` and `sun_requirement` (currently only type, brand, cycle, and search are supported).

### Sort

- Clickable `↕` indicators on all table column headers: Name, Type, Brand, Cycle, Plant In
- Clicking a header sends a `"sort"` event with `%{"field" => field}`
- `IndexLive` tracks `sort_field` and `sort_dir` in assigns (default: `name` / `asc`)
- Clicking the active column toggles direction (`asc` → `desc` → `asc`); clicking a different column resets to `asc`
- `Seeds.list_seeds/1` extended to accept `sort` option and apply `ORDER BY` accordingly
- Active sort column shows `↑` (asc) or `↓` (desc); inactive columns show `↕` in a muted color

### Desktop Table

Unchanged structure, restyled:
- Container: `rounded-xl border border-[#bbf7d0] overflow-hidden`
- Header row: `bg-[#f0fdf4]`, `border-b-2 border-[#bbf7d0]`, `text-[#14532d]`
- Rows: alternating white / `#fafafa`, hover `bg-[#f0fdf4]`, `cursor-pointer`
- Type column: color-coded badge per the badge spec above
- Name: `font-semibold text-[#14532d]`

### Mobile Card Grid (responsive)

At `sm` breakpoint and below, the table is hidden and a 2-column card grid is shown instead.

Each card:
- `rounded-xl border border-[#bbf7d0] bg-white p-3`
- Top border: 3px solid, color matches type badge color
- Seed name: bold, `text-[#14532d]`
- Type badge beneath name
- Brand in muted gray
- Planting window with 🌱 prefix

Implementation: use Tailwind's `hidden sm:block` / `block sm:hidden` to toggle between table and grid.

---

## Seed Detail (`/seeds/:id`)

**File:** `lib/backyard_garden_web/live/seeds/show_live.html.heex`

### Layout

Two-column grid on `md` breakpoint and above; single column on mobile.

```
[ Key Facts (1fr) ] [ Growing Content (1.6fr) ]
```

### Left Column — Key Facts Panel

White card (`rounded-xl border border-[#bbf7d0] p-5`):
- Seed name (bold, `text-[#14532d]`) + type badge (top right)
- Attribute rows: Brand, Cycle, Planting Method, Ideal Planting Time, Days to Maturity, Sun Requirement
  - Each row: label in `#6b7280` left, value in `#14532d font-medium` right
  - Separated by `border-b border-[#f0fdf4]`
- "View on Supplier Site ↗" button at bottom (only if `supplier_product` present)
  - Styled: `bg-[#2d6a4f] text-white rounded-lg`, full width

### Right Column — Growing Content

Two cards stacked vertically:

**"From the Supplier" card** (only if `supplier_product` present):
- Standard white card with `#bbf7d0` border
- Section label: "FROM THE SUPPLIER" in `#52b788`, uppercase
- Renders `description_html` via `raw/1`

**"Growing Guide" card** (only if `care_html` present):
- White card with `#bbf7d0` border and `border-l-4 border-l-[#2d6a4f]` left accent
- Section label: "📖 GROWING GUIDE" in `#2d6a4f`, uppercase
- Renders `care_html` via `raw/1`

**Notes** (if present):
- Rendered as the first card in the right column, above the supplier content
- If neither supplier nor care content exists, notes is the only card in the right column

### Back Link

`← Seed Library` in `#2d6a4f` at top of page, above the two-column grid.

---

## Responsive Breakpoints

| Breakpoint | Seed Library | Seed Detail |
|---|---|---|
| Mobile (`< sm`) | 2-column card grid | Single column stack |
| Desktop (`≥ sm`) | Table with sort/filter | Two-column layout |

---

## Out of Scope

- Dark mode updates (the dark DaisyUI theme is kept as-is; botanical palette only applied to light theme)
- My Garden, Calendar, Settings pages (Phase 2+)
- Seed photos on cards (future consideration)
- Animation or transition polish beyond existing Tailwind hover states
