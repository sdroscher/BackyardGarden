# UX Improvements Design

**Date:** 2026-04-04
**Branch:** improve-ux
**Scope:** Approach B — targeted UX fixes + connected garden (seed detail as entry point to logging)

## Problem Statement

The app has functional data and pages but several UX gaps make it frustrating to use:
- Navigation has no active state — users can't tell what page they're on
- Workflows are disconnected — seeing a seed that needs planting has no path to logging it without navigating away and filling a form from scratch
- The seed library doesn't signal which seeds are currently in their planting window
- Calendar events are anonymous coloured dots — no seed names, no context
- Weather is implemented but invisible without an API key, and the dashboard message isn't contextual
- README has no weather setup docs

## Design

### 1. Navigation — wire up and add active state

`Layouts.app/1` contains a fully-written nav, but the `live_view/0` definition in `backyard_garden_web.ex` never sets a default layout, so the nav is never rendered. Every LiveView currently gets only the bare `root.html.heex` skeleton.

**Step 1 — wire up the layout.** Add `layout: {BackyardGardenWeb.Layouts, :app}` to `live_view/0` in `backyard_garden_web.ex`:

```elixir
def live_view do
  quote do
    use Phoenix.LiveView,
      layout: {BackyardGardenWeb.Layouts, :app}
    ...
  end
end
```

**Step 2 — add active state.** The `nav_link` component currently renders all links identically. Update it to highlight the current page:

- Active link: `text-white border-b-2 border-white` (bright white underline)
- Inactive link: `text-[#95d5b2] border-b-2 border-transparent hover:text-white` (transparent border maintains height)

Pass `@uri.path` (automatically available in LiveView assigns) into the layout via the `current_scope` slot or a new `current_path` attr. Prefix matching is sufficient: `/seeds` matches `/seeds`, `/seeds/:id`, `/seeds/:id/edit`.

### 2. Dashboard — weather card with contextual messaging

The weather card already shows temperature and condition. Add a natural language contextual message panel that combines weather state with garden state:

**Message logic (generate in `Weather.Tips` or a new `Dashboard.WeatherMessage` module):**
- If temp > 15°C, no rain, and `plant_now` list is non-empty: "Beautiful planting weather — mild temperatures and no rain forecast. You have N seeds ready to go in the ground today."
- If temp > 15°C and `plant_now` is empty: "Great day to be outside. Check your garden for watering or weeding."
- If cold weather coming (forecast drop > 5°C): "Cold snap forecast — consider covering fragile seedlings."
- Frost warning (already implemented): displayed as amber banner, unchanged.
- Weather unavailable: card hidden entirely (current behaviour, unchanged).

The contextual message appears in a `bg-[#f0fdf4]` panel to the right of the temperature.

### 3. Dashboard — inline quick-log form on "Plant Now"

Each row in the "Plant Now" list gets a "Log it →" button (right-aligned, `bg-[#2d6a4f] text-white`).

Clicking a row's button:
1. Expands an inline form below that row (accordion, pushes other rows down)
2. Any previously expanded row collapses
3. Form fields (in a 2-column grid on wider screens, single column on mobile):
   - **Date planted** — date input, defaults to today
   - **Status** — select: Planted (default) / Planned
   - **Garden zone** — select populated by `GardenZones.recommend_zones/1` for that seed; best match pre-selected with a ★ prefix; "— no zone —" option included
   - **Location** — text input, optional
   - **Notes** — textarea, 2 rows, optional
4. Below the Save button: a preview line showing what will be saved — e.g. "Basil (Genovese) · Planted · Apr 4 · Raised Bed 2"
5. On save: collapses the form, removes the seed from the list (it's been logged), shows a flash success message

LiveView events: `"expand_quick_log"` (with `seed_id`), `"collapse_quick_log"`, `"save_quick_log"` (with changeset validation), `"validate_quick_log"`.

Socket assigns needed: `@expanded_seed_id`, `@quick_log_form`, `@quick_log_zones`.

### 4. Seed detail page — Log Planting entry point

Add to the left column of `Seeds.ShowLive`, below the key facts card:

- **"In season now" badge** — shown when today's date falls within the seed's `ideal_planting_time` range (uses the existing `PlantingCalendar.parse_planting_time/1`). Style: `bg-[#dcfce7] text-[#16a34a] border border-[#86efac]` pill.
- **"+ Log Planting" button** — full width, `bg-[#2d6a4f] text-white`. Clicking expands the same inline form used on the dashboard (same fields, same zone recommendation logic), rendered below the facts card. The seed is pre-filled and the selector is omitted since context is clear.

LiveView events: `"show_log_form"`, `"hide_log_form"`, `"save_planting"`, `"validate_planting"`. Reuse the existing changeset and zone recommendation logic from `Garden.IndexLive`.

### 5. Seed library — in-season status column

Add a **Status** column to the seed table (desktop) and a status indicator to the mobile card grid:

- **In season** (today within window): `🌱 In season` — `bg-[#dcfce7] text-[#16a34a] border border-[#86efac]` pill; row gets `bg-[#f0fdf4]` tint
- **Opening soon** (window starts within 30 days): `⏳ In N weeks` — `bg-[#fef3c7] text-[#92400e] border border-[#fcd34d]` pill
- **Out of season**: empty cell (no badge, no tint)

The in-season calculation uses `PlantingCalendar.parse_planting_time/1` on each seed's `ideal_planting_time`. Compute this in the LiveView `mount` / `handle_event("filter")` so it's available as a precomputed field on each seed struct or as a separate map keyed by seed ID.

The mobile card grid gets the same badge instead of the current `🌱 {ideal_planting_time}` text line.

### 6. Calendar — named event chips

Replace anonymous coloured dots with labelled chips showing the seed name:

- **"🌱 {seed name} window"** — `bg-[#dcfce7] text-[#16a34a]`; shown only on the first day of the seed's planting window (avoids filling every cell for the entire window duration)
- **"✓ {seed name} planted"** — `bg-[#dbeafe] text-[#1d4ed8]`; shown on the planting date
- **"⚡ {seed name} harvest"** — `bg-[#fef9c3] text-[#854d0e]`; shown on the estimated harvest date

Each chip is `text-[10px] rounded px-1 truncate` (existing style), max 2 chips per cell with "+N more" overflow (existing behaviour, unchanged).

**Today** gets `outline: 2px solid #52b788` and `bg-[#f0fdf4]` to make the current date obvious.

Legend updated to show the chip style samples instead of coloured dots.

The `events_by_date` map (built in `Calendar.IndexLive`) currently maps date → list of atoms (`:planted`, `:harvest_due`). Change it to map date → list of `{event_type, seed_name}` tuples so chips can display the name.

### 7. README — weather setup docs

Add a **Weather** section to README.md covering:
- Requires an OpenWeatherMap free-tier API key
- Set `OPENWEATHERMAP_API_KEY=<key>` in your environment (or `.env` file if using `dotenv`)
- Default location is `"Victoria, BC"` — override with `config :backyard_garden, :default_location, "Your City"` in `config/dev.exs`
- Without the key the weather card is silently hidden — this is intentional

### 8. Visual redesign — Garden Journal aesthetic

Replace the current flat/boxy card style with a warmer, more characterful design across all pages. The green colour palette is unchanged; the changes are to shape, depth, and layout.

**Sizing note:** The HTML mockups look correct at ~125% browser zoom, meaning the implementation should be scaled up from the mockup values. Treat the mockup as the right *proportions* but increase font sizes and padding by roughly 15% throughout — see specific values below.

**Page & layout:**
- Page background: `#fafdf9` (near-white with a hint of green, replaces `bg-[#f0fdf4]`)
- Page content capped at `max-width: 1280px`, centred with `padding: 28px 32px` (scales down to `20px 16px` on mobile)
- A personalised greeting replaces the bare `<h1>` on the dashboard: "Good morning, happy Saturday 🌤" (day + weather icon derived from current conditions)

**Typography scale (Tailwind equivalents):**
- Row item names: `text-sm` (14px) — not `text-xs`
- Sub-labels / metadata: `text-xs` (12px)
- Card header titles: `text-base font-bold` (16px)
- Dashboard greeting: `text-3xl font-extrabold` (30px)
- Weather temperature: `text-6xl font-black` (60px)
- Card body padding: `p-5` or `p-6` — not `p-4`
- Row padding: `py-3` — not `py-2`

**Cards:**
- Border radius: `22px` (up from `12px`)
- White background with `box-shadow: 0 2px 20px rgba(0,0,0,0.07)` — no border
- Each card has a coloured gradient header bar containing the section title in white:
  - Plant Now / in-season elements: `linear-gradient(135deg, #2d6a4f, #52b788)`
  - Recently Planted: `linear-gradient(135deg, #7c3aed, #a78bfa)`
  - Coming Up: `linear-gradient(135deg, #d97706, #fbbf24)`
  - Settings/neutral sections: `linear-gradient(135deg, #374151, #6b7280)`
- The weather card is not a white card — it uses `linear-gradient(150deg, #ecfdf5, #d1fae5)` with a large faded weather emoji as decoration and a white inset tip box

**Buttons:**
- Primary action buttons (Log it, Save, etc.): pill shape (`border-radius: 999px`), `background: linear-gradient(135deg, #2d6a4f, #52b788)`
- Secondary/cancel buttons: white background, `border: 1px solid #e5e7eb`, standard border-radius

**Nav:**
- Dark gradient: `linear-gradient(90deg, #0f1f15, #1a3a2a, #2d6a4f)`, full width
- Active link: `background: rgba(255,255,255,0.12)`, `color: white`, `border-radius: 9px`
- Inactive links: `color: rgba(255,255,255,0.45)`, no underline
- On screens < 540px: non-active nav links hidden (hamburger menu out of scope for this phase)

**Dashboard layout (responsive grid):**

All four dashboard cards sit directly in a CSS grid (no nested wrappers):

```
Desktop (>780px):   [ weather (2fr)   ] [ recently planted (1fr) ]
                    [ plant now (2fr) ] [ coming up (1fr)        ]

Tablet (440–780px): [ weather (full width)    ]
                    [ plant now (full width)  ]
                    [ recently planted ] [ coming up ]

Mobile (<440px):    single column, all stacked
```

Grid stretches cards in the same row to equal height, so row tops always align.

**Other pages (Seeds, My Garden, Calendar, Zones):**
- Same card shell (22px radius, shadow, gradient header bar) applied consistently
- Table rows: hover state `bg-[#f0fdf4]`, no change to column structure
- Forms: inputs keep existing border style; submit buttons use the new pill gradient style

## Out of Scope

- Zone management UI changes (existing `/settings/zones` page is sufficient; nav active state makes it discoverable)
- Auth, mobile app, iOS notifications (future phases)
- Hamburger/drawer mobile nav (non-active links hidden on small screens is sufficient for this phase)

## Affected Files

| File | Change |
|---|---|
| `lib/backyard_garden_web.ex` | Wire up `Layouts.app` as default LiveView layout |
| `lib/backyard_garden_web/components/layouts.ex` | Nav active state |
| `lib/backyard_garden_web/live/dashboard/index_live.ex` | Quick-log assigns + events |
| `lib/backyard_garden_web/live/dashboard/index_live.html.heex` | Weather message, Plant Now rows + inline form |
| `lib/backyard_garden/weather/tips.ex` | Contextual message logic (takes `plant_now` count) |
| `lib/backyard_garden_web/live/seeds/show_live.ex` | Log form assigns + events |
| `lib/backyard_garden_web/live/seeds/show_live.html.heex` | In-season badge + Log Planting button + inline form |
| `lib/backyard_garden_web/live/seeds/index_live.ex` | In-season precomputation |
| `lib/backyard_garden_web/live/seeds/index_live.html.heex` | Status column + mobile badge |
| `lib/backyard_garden_web/live/calendar/index_live.ex` | events_by_date tuple format |
| `lib/backyard_garden_web/live/calendar/index_live.html.heex` | Named chips, today highlight, legend |
| `README.md` | Weather setup section |
| `lib/backyard_garden_web/components/layouts/app.html.heex` | Nav dark gradient, active state, pill links |
| `lib/backyard_garden_web/components/layouts/root.html.heex` | Page background colour |
| All `*.html.heex` templates | Card shells, gradient headers, pill buttons, responsive grid |
