# BackyardGarden

A mobile-responsive web app for managing planting schedules, tracking seed plantings, and receiving iOS reminders via Prowl.

Built with **Elixir + Phoenix LiveView**, deployed to **fly.io**.

## Features

**Phase 1 — Complete**
- Seed library with live search and filtering (62 seeds)
- Seed detail pages

**Phase 1.5 — Complete**
- Supplier catalog scraped from West Coast Seeds and Metchosin Farm (Shopify JSON API)
- Fuzzy name matching links seeds to supplier products (`mix supplier.scrape`, `mix supplier.match`, `mix supplier.link`)
- Seed detail page shows "From the Supplier" section with care HTML and link to product page

**Phase 2 — Complete**
- Dashboard with Plant Now list, Recently Planted, Coming Up schedule, and weather card
- Planting schedule tracking — planned, planted, harvested (My Garden page)
- Garden zone recommendations based on plant type, cycle, and sun requirements
- Monthly planting calendar with ideal window overlays
- Weather-aware planting tips via OpenWeatherMap

**Phase 4 — Complete**
- iOS push notifications via [Prowl](https://www.prowlapp.com/) — hourly checks dispatched at each user's preferred morning/evening times
- Notification types: plant-now, harvest-soon, sow-now, start-hardening, hardening-morning, hardening-evening, hardening-weather-warning
- Weather-aware hardening alerts: warns when rain, high wind (>40 km/h), or heat (>30°C) is forecast
- Notification settings page — configure Prowl API key, enable/disable notifications, and set morning/evening reminder times
- User context with timezone and notification settings
- Oban job infrastructure (plant checking, notification sending) — ready for deployment

**Session Improvements (April 2026)**
- Seedling tracking — full indoor lifecycle: sow in trays → harden outdoors → transplant; new planting statuses `sown` and `hardening`
- Seed edit page — edit any seed's details including new seedling fields (`weeks_to_start_indoors`, `hardening_days`)
- Edit logged plantings — inline edit form on My Garden page for any planting
- Timezone-correct date handling — all dates use the configured app timezone, not UTC
- Flash messages now appear below the navigation bar

**Phase 5+ — Planned**
- Auth0 login (Google, Apple, email)
- Multi-user support with authenticated routes
- Frost warning notifications (weather-triggered)

## Getting Started

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+ (install via [asdf](https://asdf-vm.com/))
- Phoenix 1.8+

```bash
asdf plugin add erlang && asdf install erlang 27.2
asdf plugin add elixir && asdf install elixir 1.18.2-otp-27
mix archive.install hex phx_new
```

### Environment Variables

Create a `.env` file in the project root (auto-loaded in dev via dotenvy):

```
# Weather (optional)
OPENWEATHERMAP_API_KEY=your_key_here
DEFAULT_LOCATION=Victoria,CA        # format: City,CountryCode
TIMEZONE=America/Vancouver          # IANA timezone name

# Prowl notifications (optional, Phase 4+)
# Get your API key from https://www.prowlapp.com/
# Leave blank to disable Prowl notifications
PROWL_API_KEY=your_prowl_key_here
```

**Env var defaults:**
- `DEFAULT_LOCATION` and `TIMEZONE` have sensible defaults if omitted
- `OPENWEATHERMAP_API_KEY`: Weather card is silently hidden if missing
- `PROWL_API_KEY`: Set via the `/settings/notifications` page (no env var required)

### Setup

```bash
# Install deps, create & migrate DB, import seed data, build assets
mix setup

mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

### Tests

```bash
mix test
```

## Weather Integration

The dashboard shows current conditions and a contextual planting tip powered by [OpenWeatherMap](https://openweathermap.org/api).

Set `OPENWEATHERMAP_API_KEY` in `.env` (auto-loaded in dev). Location format must be `City,CountryCode` (e.g. `Victoria,CA`) — province/state names are not supported by the API. The weather card is silently hidden if the key is missing.

## Project Structure

```
lib/
  backyard_garden/          # business logic (contexts)
    seeds/                  # Seeds context + schema (includes seedling fields)
    supplier_catalog/       # SupplierCatalog context, SupplierProduct schema, scrapers
    plantings/              # Plantings context + schema (planned/sown/hardening/planted/harvested)
    garden_zones/           # GardenZones context + zone recommendation engine
    users/                  # Users context (timezone, notification prefs)
    notifications/          # Notifications context + delivery tracking
    workers/                # Oban workers: HourlyCheckWorker, ProwlNotifierJob
    weather/                # Weather facade, HTTP client, ETS cache, tip generation
    dashboard/              # Dashboard query functions
  backyard_garden_web/      # web layer (LiveViews, router, layouts)
  mix/tasks/                # mix supplier.scrape / match / link
priv/
  repo/
    migrations/             # Ecto migrations
    seeds.exs               # CSV seed import script
docs/
  Requirements.md           # original requirements
  superpowers/
    specs/                  # design specs
    plans/                  # implementation plans (phase by phase)
```

## Implementation Plan

See [Plan.md](./Plan.md) for architecture decisions, data model, UI mockups, and phased implementation tasks.

Detailed task-by-task plans are in `docs/superpowers/plans/`.

## Deployment

Targeted at [fly.io](https://fly.io). SQLite with a persistent volume for local/dev; Postgres migration path is documented in Plan.md.

```bash
fly launch
fly deploy
```

## Prowl Notifications (Phase 4)

Receive iOS push notifications for planting events and seedling reminders.

### Setup

1. Install [Prowl](https://www.prowlapp.com/) on your iOS device (free app)
2. Get your Prowl API key from [https://www.prowlapp.com/](https://www.prowlapp.com/)
3. Add it via the settings page at `/settings/notifications`
4. Set your preferred morning and evening reminder times on the same page

### Hourly Job

The app includes an Oban job (`HourlyCheckWorker`) that runs at the top of every hour. For each user it checks whether the current local hour matches their configured morning or evening reminder time, then sends the appropriate notifications.

**Morning checks:**
- **Plant Now** — seeds whose ideal planting window is open and haven't been planted yet
- **Harvest Soon** — planted items within 7 days of harvest maturity
- **Sow Now** — seedling plantings where today is the calculated indoor sow date
- **Start Hardening** — seedlings that are ready to begin outdoor hardening
- **Hardening Morning** — reminder to take seedlings outside (skipped if a weather warning is sent instead)
- **Hardening Weather Warning** — rain, high wind (>40 km/h), or heat (>30°C) forecast; warns to keep seedlings inside

**Evening checks:**
- **Hardening Evening** — reminder to bring seedlings inside for the night

**Known Issue:** Oban supervisor startup is currently commented out in `lib/backyard_garden/application.ex` due to SQLite+testing mode configuration. The job infrastructure is complete; uncomment the supervisor line once notifier configuration is finalized (auto-works with Postgres in Phase 6+).

### Testing

To manually test notifications in dev:

```elixir
# In iex -S mix:
user = BackyardGarden.Users.get_user_by_email("simon@droscher.com")

# Create a test notification
{:ok, notif} = BackyardGarden.Notifications.log_notification(%{
  "user_id" => user.id,
  "type" => "plant_now",
  "message" => "Test notification"
})

# Manually enqueue the Prowl job
BackyardGarden.Workers.ProwlNotifierJob.new(%{"notification_id" => notif.id})
|> Oban.insert()
```

## Supplier Catalog

Seed detail pages can show care information scraped from supplier Shopify stores. Three mix tasks manage this:

```bash
# Fetch and upsert all products from West Coast Seeds and Metchosin Farm
mix supplier.scrape

# Import a single product by URL (useful for products missed by the bulk scrape)
mix supplier.scrape https://www.westcoastseeds.com/products/bright-lights-1

# Fuzzy-match seeds to supplier products (auto-links ≥ 0.90 score, prints review list for 0.75–0.89)
mix supplier.match

# Manually link a seed to a product — accepts a UUID, handle, or full product URL
mix supplier.link <seed_id> <product_id|handle|url>

# Examples:
mix supplier.link <seed_id> https://metchosinfarm.ca/products/noche-zucchini
mix supplier.link <seed_id> noche-zucchini
```

Run `mix supplier.scrape` first to populate the catalog, then `mix supplier.match` to link seeds. Re-running either task is safe — scrape uses upsert and match skips already-linked seeds.

## Seed Data

Initial seed data sourced from:
- [Metchosin Farm Seed Library](https://metchosinfarm.ca/collections/all-seeds)
- [West Coast Seeds](https://www.westcoastseeds.com/)
