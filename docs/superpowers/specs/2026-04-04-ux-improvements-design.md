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

### 1. Navigation active state

The `nav_link` component in `Layouts.app/1` currently renders all links identically. Add active state detection using the current request path:

- Active link: `text-white border-b-2 border-white` (bright white underline)
- Inactive link: `text-[#95d5b2] border-b-2 border-transparent hover:text-white` (current style, transparent border to maintain height)

The `LiveView` assigns `@current_path` (or use `URI.parse(@url).path` from the socket) to detect the active route. Prefix matching is sufficient: `/seeds` matches `/seeds`, `/seeds/:id`, `/seeds/:id/edit`.

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

## Out of Scope

- Zone management UI changes (existing `/settings/zones` page is sufficient; nav active state makes it discoverable)
- Auth, mobile app, iOS notifications (future phases)
- Any visual design language changes (Botanical & Lush spec already in place)

## Affected Files

| File | Change |
|---|---|
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
