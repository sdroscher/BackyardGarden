# BackyardGarden — Implementation Plan

A mobile-responsive web app for managing planting schedules, tracking seed plantings, and receiving care reminders. Primary user: simon@droscher.com, with initial data seeded from `Seed Planting 2026.csv`.

---

## Tech Stack Decision

**Chosen: Elixir + Phoenix** ✅

See the comparison sections below for reference. Key reasons: first-class fly.io support, LiveView for real-time UI without JavaScript, Oban for reliable notification scheduling, and a one-line Postgres migration path.

---

### Option A: GOTH Stack (Go + Templ + HTMX + Tailwind)

**What it is:** Go backend with type-safe HTML templates (Templ), dynamic UI via HTMX (server-driven, no JS framework), styled with Tailwind CSS.

**Pros:**
- Single binary — trivial to run locally (`./backyard-garden`), easy Docker image for fly.io
- Very low memory footprint (~20 MB vs ~150 MB for BEAM)
- Templ catches template errors at compile time (no runtime panics on bad HTML)
- HTMX means dynamic search/filters without writing JavaScript
- Fast build times, excellent tooling (gopls, golangci-lint)
- Go's goroutines make background notification jobs straightforward
- SQLite driver (mattn/go-sqlite3) is mature and well-supported

**Cons:**
- No auth generator — Auth0 SDK integration requires more manual wiring
- More boilerplate than Rails/Phoenix for common CRUD patterns
- Go's html/template is verbose; Templ helps but adds a build step
- Migrating SQL from SQLite → Postgres requires dialect review (e.g. `AUTOINCREMENT` vs `SERIAL`)
- Background job scheduling is manual (cron library) vs Elixir's Oban

**Best fit if:** You want to learn Go, prefer explicit code over magic, or need a dead-simple deployment story.

---

### Option B: Elixir + Phoenix ⭐ Chosen

**What it is:** Elixir backend with Phoenix web framework, LiveView for real-time UI, Ecto ORM, Oban for background jobs.

**Pros:**
- **Designed for fly.io** — Phoenix and fly.io share DNA; `fly launch` just works
- **LiveView** makes the dashboard and calendar update in real-time without writing JavaScript
- **`mix phx.gen.auth`** plus Auth0's Elixir SDK means auth is fast to set up
- **Oban** (background jobs) is best-in-class for scheduled notifications — retry logic, scheduling, visibility all built in
- **Ecto migrations** are SQL-first; swapping SQLite → Postgres is a one-line config change
- Pattern matching makes planting schedule logic clean and readable
- Excellent test tooling (ExUnit, Mox)

**Cons:**
- Steeper learning curve if unfamiliar with functional programming or the BEAM/OTP model
- Local setup requires installing both Elixir and Erlang (asdf makes this easy)
- Smaller community than Go or Python
- LiveView has its own mental model (sockets, assigns, events) — takes a session to grok
- Slightly more complex debugging than a synchronous Go server

**Best fit if:** You want the cleanest path to fly.io deployment, want live-updating UI without JavaScript complexity, or plan to add real-time features later.

**Postgres migration path:** Change `config :app, App.Repo, adapter: Ecto.Adapters.Postgres` and run `mix ecto.migrate`. Ecto's migrations are database-agnostic — no SQL dialect changes needed.

---

### Option C: Flutter (Multi-platform App) — Lesser Likely

**What it is:** Flutter frontend (Dart) targeting iOS, Android, and web, backed by a REST API (Go or Elixir).

**Pros:**
- Native iOS app → native APNs push notifications (no Prowl needed)
- One codebase for iOS, Android, web, and desktop
- Excellent native mobile UX — gestures, animations, offline-capable
- Can replace Prowl dependency entirely

**Cons:**
- **Requires building two things:** a Flutter frontend AND a backend REST API — effectively doubles the scope
- Adds Dart as a second language
- Apple Developer account required for TestFlight/App Store ($99/yr)
- Flutter web performance is inferior to a well-built responsive web app
- Much larger scope for a personal single-user gardening app
- CI/CD for app releases is more complex than web deploys

**Best fit if:** You want a polished native mobile experience and plan to distribute the app to others. Overkill for personal use at home.

---

## Architecture (Recommended: Elixir + Phoenix)

```
┌─────────────────────────────────────────────────────┐
│                    fly.io (or localhost)             │
│                                                     │
│  ┌──────────────┐    ┌─────────────────────────┐   │
│  │   Phoenix    │    │   Oban (background jobs) │   │
│  │   LiveView   │    │   - daily planting check │   │
│  │   REST API   │    │   - Prowl notifications  │   │
│  └──────┬───────┘    └───────────┬─────────────┘   │
│         │                        │                   │
│  ┌──────▼────────────────────────▼─────────────┐   │
│  │              Ecto ORM                        │   │
│  └──────────────────┬───────────────────────────┘   │
│                     │                               │
│  ┌──────────────────▼───────────────────────────┐   │
│  │    SQLite (dev) / Postgres (prod)             │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
         │                      │
   ┌─────▼──────┐      ┌────────▼──────┐
   │   Auth0    │      │ OpenWeatherMap│
   │ (OAuth/    │      │ API (cached   │
   │  Google)   │      │  1hr in ETS)  │
   └────────────┘      └───────────────┘
         │
   ┌─────▼──────┐
   │ Prowl API  │
   │ (iOS push) │
   └────────────┘
```

---

## Data Model

```sql
-- Users (managed primarily via Auth0, local record for preferences)
users
  id            UUID primary key
  email         string unique not null
  name          string
  auth0_id      string unique          -- Auth0 subject identifier
  location      string                  -- e.g. "Victoria, BC" for weather
  timezone      string default "America/Vancouver"
  prowl_api_key string                  -- encrypted at rest
  inserted_at   timestamp
  updated_at    timestamp

-- Seed reference data (imported from CSV + enriched over time)
seeds
  id                  UUID primary key
  name                string not null
  brand               string             -- "Metchosin Farm" | "West Coast Seeds"
  type                string             -- "Vegetable" | "Herb" | "Flower" | "Berry"
  cycle               string             -- "Annual" | "Perennial" | "Biennial"
  planting_method     string             -- "Direct Sow" | "Seedlings"
  ideal_planting_time string             -- human-readable, e.g. "Early Spring"
  maturity_days       integer
  sun_requirement     string             -- "full_sun" | "partial_sun" | "shade_tolerant"
  source_url          string
  notes               text
  inserted_at         timestamp
  updated_at          timestamp

-- Configurable planting zones (pre-seeded with Simon's garden, user-editable)
garden_zones
  id               UUID primary key
  user_id          UUID references users
  name             string             -- e.g. "Sunny Raised Planters", "Herb Boxes", "Back Garden"
  description      text               -- optional free-text notes about the zone
  sun_exposures    string             -- comma-separated: "full_sun" or "full_sun,partial_sun,shade"
  allowed_types    string             -- comma-separated: "vegetable" — empty means no restriction
  allowed_cycles   string             -- comma-separated: "annual" — empty means no restriction
                                     -- Note: stored as comma-separated strings in SQLite;
                                     -- Postgres migration can convert to native array columns
  inserted_at      timestamp
  updated_at       timestamp

-- A user's garden plantings
plantings
  id              UUID primary key
  user_id         UUID references users
  seed_id         UUID references seeds
  zone_id         UUID references garden_zones (nullable)
  status          string     -- "planned" | "planted" | "harvested"
  planted_at      date
  harvested_at    date
  location        string     -- free-text spot within zone, e.g. "east end of bed"
  notes           text
  inserted_at     timestamp
  updated_at      timestamp

-- Notifications (Prowl delivery log)
notifications
  id              UUID primary key
  user_id         UUID references users
  planting_id     UUID references plantings (nullable — can be general)
  type            string     -- "plant_now" | "water" | "harvest_soon"
  message         text
  scheduled_at    timestamp
  sent_at         timestamp
  prowl_response  string
  inserted_at     timestamp
```

---

## Pages & Routes

| Route | Page | Description |
|---|---|---|
| `GET /` | Dashboard | Weather widget, plant-now list, recently planted, upcoming schedule |
| `GET /seeds` | Seed Library | Browse/search/filter all seeds |
| `GET /seeds/:id` | Seed Detail | Full seed info, care instructions, planting history |
| `GET /garden` | My Garden | Planted/planned/harvested items by status |
| `POST /garden` | — | Log a new planting |
| `PATCH /garden/:id` | — | Update planting status |
| `GET /calendar` | Planting Calendar | Month view, colour-coded by type |
| `GET /settings` | Settings | Profile, location, Prowl API key, notification prefs |
| `GET /auth/callback` | — | Auth0 OAuth callback |

---

## UI Mockups

### Dashboard

```
┌──────────────────────────────────────────────────────────┐
│  🌱 BackyardGarden                    Simon  ⚙ Settings  │
├──────────────────────────────────────────────────────────┤
│  📍 Victoria, BC   ☁  12°C   Light rain today            │
│  Tip: Good conditions for sowing cool-weather crops!     │
├─────────────────────────┬────────────────────────────────┤
│  🌱 Plant Now           │  ✓ Recently Planted            │
│                         │                                │
│  • Spinach              │  Spinach          Mar 27       │
│  • Swiss Chard          │  Swiss Chard Mix  Mar 27       │
│  • Carrots              │                                │
│  • Echinacea            │                                │
│  • Chamomile            │                                │
├─────────────────────────┴────────────────────────────────┤
│  📅 Coming Up                                            │
│                                                          │
│  Apr 1   Bush Beans        ideal window opens            │
│  Apr 15  Peppers           start seedlings indoors       │
│  Apr 30  Zucchini          direct sow window opens       │
│  May 1   Pole Beans        direct sow window opens       │
└──────────────────────────────────────────────────────────┘
```

### Seed Library

```
┌──────────────────────────────────────────────────────────┐
│  Seed Library (62 seeds)      [🔍 Search seeds...]  [+]  │
│  Type: [All ▼]  Brand: [All ▼]  Cycle: [All ▼]           │
├────────────────────┬──────────┬────────────┬─────────────┤
│ NAME               │ TYPE     │ BRAND      │ PLANT IN    │
├────────────────────┼──────────┼────────────┼─────────────┤
│ Anise Hyssop       │ Herb     │ Metchosin  │ Spring      │
│ Beets - Blend      │ Veg      │ WC Seeds   │ Apr – Jul   │
│ Beets - Boro       │ Veg      │ WC Seeds   │ Apr – Jul   │
│ Borage             │ Herb     │ Metchosin  │ Spring      │
│ Bush Beans - Mix   │ Veg      │ Metchosin  │ Late Apr    │
│ Calendula          │ Herb     │ Metchosin  │ Early Spring│
│ ...                │          │            │             │
└────────────────────┴──────────┴────────────┴─────────────┘
```

### My Garden

```
┌──────────────────────────────────────────────────────────┐
│  My Garden                              [+ Log Planting]  │
├──────────────────────────────────────────────────────────┤
│  ● PLANTED (2)                                           │
│                                                          │
│  Spinach           Planted Mar 27  Ready ~May 16         │
│                    New garden near Raspberries            │
│                                                          │
│  Swiss Chard Mix   Planted Mar 27  Ready ~May 26         │
│                    New garden near Raspberries            │
│                                              [Mark Harvested]│
├──────────────────────────────────────────────────────────┤
│  ○ PLANNED (4)                                           │
│                                                          │
│  Bush Beans - Mix    Ideal: Late Apr    [Mark Planted]   │
│  Carrots             Ideal: Early Apr   [Mark Planted]   │
│  Zucchini - Noche    Ideal: Late Apr    [Mark Planted]   │
│  Peppers - CA Wonder Ideal: Mar         [Mark Planted]   │
├──────────────────────────────────────────────────────────┤
│  ✓ HARVESTED (0)                                         │
└──────────────────────────────────────────────────────────┘
```

### Planting Calendar

```
┌──────────────────────────────────────────────────────────┐
│  [← Mar]     April 2026     [May →]                      │
├────┬────┬────┬────┬────┬────┬────┐                       │
│ Mo │ Tu │ We │ Th │ Fr │ Sa │ Su │                       │
├────┼────┼────┼────┼────┼────┼────┤                       │
│    │    │  1 │  2 │  3 │  4 │  5 │                       │
│    │    │🟢BS│    │    │    │    │  🟢 Ideal window open │
├────┼────┼────┼────┼────┼────┼────┤  🔵 Planted           │
│  6 │  7 │  8 │  9 │ 10 │ 11 │ 12 │  🟡 Harvest soon      │
│    │    │    │    │    │    │    │                       │
├────┼────┼────┼────┼────┼────┼────┤                       │
│ 13 │ 14 │ 15 │ 16 │ 17 │ 18 │ 19 │                       │
│    │    │🟢PP│    │    │    │    │  🟢PP = Pepper seedl. │
└────┴────┴────┴────┴────┴────┴────┘                       │
└──────────────────────────────────────────────────────────┘
```

---

## Notifications (Prowl)

You already have Prowl installed on your iOS device. The app sends notifications via a simple HTTP POST to the Prowl API.

Daily Oban job (runs at 7am local time) checks:

1. **Plant Now** — seeds whose `ideal_planting_time` window is open and not yet planted
2. **Harvest Soon** — planted items whose `planted_at + maturity_days` is within 7 days
3. **Frost Warning** — if weather API forecasts frost and tender plants are in the ground

**Prowl API call:**
```
POST https://api.prowlapp.com/publicapi/add
  apikey=<prowl_api_key>
  application=BackyardGarden
  event=Plant Now
  description=Bush Beans ideal window opens today
  priority=0
```

**Alternatives if Prowl is unavailable:**
- **ntfy.sh** — free, open source, has its own iOS app, self-hostable
- **Pushover** — $5 one-time iOS app purchase, very similar API

---

## Weather Integration

- Provider: **OpenWeatherMap** (free tier — 1,000 calls/day)
- Cache: ETS table (Elixir in-memory), 1-hour TTL
- Data used: current temp, condition, 3-day forecast (for frost warning)
- Location stored per-user as a city string, resolved to lat/lon on first use

---

## Auth (Auth0)

- Users log in via Auth0 (Google, Apple, or email+password)
- On first login, a `users` record is created locally with their Auth0 subject ID
- Session stored server-side (Phoenix session cookie)
- `prowl_api_key` stored encrypted in the database (Cloak library)

---

## Garden Zones

Zones let you define areas of the garden with constraints, and the app recommends which zone(s) a seed belongs in when logging a planting.

### Default zones (pre-seeded for simon@droscher.com)

| Zone | Sun | Allowed Types | Allowed Cycles |
|---|---|---|---|
| Sunny Raised Planters | Full sun | Vegetables | Annuals only |
| Herb Boxes | Full sun, partial sun, or shade (per herb needs) | Herbs | Any |
| Back Garden | Full sun, partial sun, shade | Any | Perennials, biennials |

### Recommendation logic

When logging a planting, the app computes matching zones by:

1. **Type match** — seed type is in `allowed_types` (or zone has no type restriction)
2. **Cycle match** — seed cycle is in `allowed_cycles` (or zone has no cycle restriction)
3. **Sun match** — seed's `sun_requirement` overlaps with zone's `sun_exposures`

The best-matching zone is suggested as the default; others are shown as alternatives.

Example:
- **Borage** (Herb, Annual, full sun) → Herb Boxes (full sun position)
- **Bush Beans** (Vegetable, Annual) → Sunny Raised Planters
- **Echinacea** (Herb, Perennial) → Back Garden (not Herb Boxes, because it's perennial)
- **Catnip** (Herb, Perennial, partial shade) → Back Garden (partial shade spot)

### Sun requirement data

The `sun_requirement` field is not in the CSV — it will need to be populated. Options:
- [ ] Manually curate for the 62 seeds (a few hours of research)
- [ ] Add a community-sourced seed enrichment step using a future seed database import
- [ ] Leave blank initially; app shows all zones as options and lets user pick

Recommend: leave blank for Phase 1, add a simple admin edit form in Phase 2 so you can fill them in as you go.

### Zone configuration UI

A simple Settings sub-page (`/settings/zones`) shows all zones as editable cards:

```
┌──────────────────────────────────────────────────────────┐
│  Garden Zones                                  [+ Add Zone]│
├──────────────────────────────────────────────────────────┤
│  ☀ Sunny Raised Planters                          [Edit] │
│  Sun: Full sun                                           │
│  Types: Vegetables only  |  Cycles: Annuals only         │
├──────────────────────────────────────────────────────────┤
│  🌿 Herb Boxes                                    [Edit] │
│  Sun: Full sun, Partial sun, Shade                       │
│  Types: Herbs only  |  Cycles: Any                       │
├──────────────────────────────────────────────────────────┤
│  🌳 Back Garden                                   [Edit] │
│  Sun: Full sun, Partial sun, Shade                       │
│  Types: Any  |  Cycles: Perennial, Biennial              │
└──────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1 — Foundation ✅ Complete

- [x] 1.1 Initialise Phoenix project with SQLite adapter (`ecto_sqlite3`)
- [x] 1.2 Create database migrations for `seeds`
- [x] 1.3 Seed database from `Seed Planting 2026.csv` (mix task)
- [x] 1.4 Basic layout (Tailwind) — nav, responsive shell
- [x] 1.5 Seed Library page — list, search (LiveView), filter by type/brand/cycle
- [x] 1.6 Seed detail page

### Phase 2 — Garden & Planting Tracking

**Carry-overs from Phase 1 review (address early in Phase 2):**
- Add Content-Security-Policy header to the browser pipeline (Sobelow `Config.CSP` advisory — required before any deployment)
- Reload type/brand/cycle filter dropdown options when seeds are created or edited (currently loaded once in `mount/3`)
- Decide on `source_url` field: expose in seed edit form or leave for later

- [ ] 2.1 My Garden page — list plantings by status
- [ ] 2.2 Log Planting form — select seed, set date, location, notes
- [ ] 2.3 Update planting status (planned → planted → harvested)
- [ ] 2.4 Planting Calendar — month view, ideal window overlays
- [ ] 2.5 Import existing plantings from CSV (`actually_planted`, `location`, `notes` columns)
- [ ] 2.6 Seed database migration — add `sun_requirement` field
- [ ] 2.7 Garden Zones — create default zones for simon@droscher.com (migration/seed data)
- [ ] 2.8 Zone recommendation — show suggested zone(s) when logging a planting
- [ ] 2.9 Seed edit form — allow setting `sun_requirement` and `source_url` per seed
- [ ] 2.10 Zone settings page (`/settings/zones`) — add/edit/delete zones

### Phase 3 — Dashboard & Weather

- [ ] 3.1 Dashboard page — plant-now list, recently planted, upcoming schedule
- [ ] 3.2 OpenWeatherMap integration — current conditions widget
- [ ] 3.3 Weather caching (ETS, 1-hour TTL)
- [ ] 3.4 Weather-aware planting tips (frost warning, soil temp guidance)

### Phase 4 — Notifications

- [ ] 4.1 Add Oban dependency, configure queues
- [ ] 4.2 Prowl notification worker (HTTP POST to Prowl API)
- [ ] 4.3 Daily scheduler — plant-now and harvest-soon checks
- [ ] 4.4 Frost warning notification (weather-triggered)
- [ ] 4.5 Notification settings page — enable/disable types, send test notification

### Phase 5 — Auth & Multi-user

- [ ] 5.1 Auth0 application setup (Google OAuth, email+password)
- [ ] 5.2 Phoenix Auth0 integration (`ueberauth_auth0`)
- [ ] 5.3 Protect routes behind authentication
- [ ] 5.4 User settings page — location, timezone, Prowl API key (encrypted)
- [ ] 5.5 Scope all garden data to authenticated user

### Phase 6 — Deployment

- [ ] 6.1 Dockerfile (multi-stage, minimal image)
- [ ] 6.2 `fly.toml` configuration — SQLite persistent volume
- [ ] 6.3 Runtime config (env vars for Auth0 credentials, secrets)
- [ ] 6.4 fly.io deploy and smoke test
- [ ] 6.5 (Optional) Postgres migration — swap `ecto_sqlite3` adapter for `postgrex`, run `mix ecto.migrate`

---

## Future Considerations

- **Postgres:** Swap `ecto_sqlite3` adapter for `postgrex`. Migrations are database-agnostic — no SQL changes expected. Provision on fly.io with `fly postgres create`.
- **Flutter:** If a native mobile app becomes desirable, the Phoenix backend can expose a JSON API with minimal changes. Auth0 already works with Flutter SDKs.
- **Multi-user / sharing:** Auth model supports multiple users; garden data is already user-scoped from day one.
- **Seed provider integration:** West Coast Seeds and Metchosin Farm URLs stored per-seed for deep linking to purchase pages.
- **Smart device integration:** Webhooks from soil moisture sensors could trigger watering notifications via the existing Prowl pipeline.
- **Plant growth tracking:** Add photos and height/weight measurements to plantings table.

---

## Key Dependencies

| Library | Purpose |
|---|---|
| `phoenix` | Web framework |
| `phoenix_live_view` | Real-time UI (search, calendar, dashboard) |
| `ecto_sqlite3` | SQLite adapter (dev/local) |
| `postgrex` | Postgres adapter (prod/fly.io, future) |
| `oban` | Background jobs / notification scheduler |
| `ueberauth_auth0` | Auth0 OAuth integration |
| `cloak_ecto` | Encrypted fields (Prowl API key) |
| `tailwind` | CSS framework |
| `req` | HTTP client (OpenWeatherMap + Prowl API calls) |
