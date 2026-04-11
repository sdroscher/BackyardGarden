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

**Phase 5 — Complete**
- Auth0 login (Google OAuth and email+password) via ueberauth_auth0
- All routes protected — unauthenticated users are redirected to Auth0
- All garden data (plantings, zones) scoped to the authenticated user
- Prowl API key encrypted at rest using Cloak AES-GCM
- Profile settings page — update name, email, location, timezone
- Logout link in nav (clears Auth0 session via `/v2/logout` so re-auth is required)

**User-Scoped Seed Library — Complete**
- Seeds are owned per-user — new users start with zero seeds
- Add Seed page (`/seeds/new`) with three modes:
  - **Supplier Catalog** — browse West Coast Seeds and Metchosin Farm products with supplier toggle filters and live search; select to pre-fill the form including supplier link
  - **From URL** — paste a `westcoastseeds.com` or `metchosinfarm.ca` product URL; app fetches and pre-fills the form
  - **Enter Manually** — free-form entry for any source
- Multi-window planting time parsing — `"Autumn,Early Spring"` correctly matches both planting windows for season badges and Plant Now recommendations

**Session Improvements (April 2026)**
- Seedling tracking — full indoor lifecycle: sow in trays → harden outdoors → transplant; new planting statuses `sown` and `hardening`
- Seed edit page — edit any seed's details including new seedling fields (`weeks_to_start_indoors`, `hardening_days`)
- Edit logged plantings — inline edit form on My Garden page for any planting
- Timezone-correct date handling — all dates use the configured app timezone, not UTC

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
# Auth0 (required — see Auth0 Setup below)
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret

# Cloak encryption key (required — see Generating a Cloak Key below)
CLOAK_KEY=base64_encoded_32_byte_key

# Weather (optional)
OPENWEATHERMAP_API_KEY=your_key_here
DEFAULT_LOCATION=Victoria,CA        # format: City,CountryCode
TIMEZONE=America/Vancouver          # IANA timezone name

# Prowl notifications (optional — configurable via /settings/notifications)
# PROWL_API_KEY=your_prowl_key_here
```

**Env var notes:**
- `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET` — required for login to work; the app will start without them but the OAuth callback will fail
- `CLOAK_KEY` — required in production; a hard-coded dev fallback is used if omitted in dev/test
- `DEFAULT_LOCATION` and `TIMEZONE` — have sensible defaults if omitted
- `OPENWEATHERMAP_API_KEY` — weather card is silently hidden if missing
- `PROWL_API_KEY` — set via the `/settings/notifications` page (no env var required)

### Setup

```bash
# Install deps, create & migrate DB, import seed data, build assets
mix setup

mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000). You will be redirected to Auth0 to log in.

### Tests

```bash
mix test
```

---

## Auth0 Setup

### 1. Create an Auth0 Application

1. Sign in to [manage.auth0.com](https://manage.auth0.com/)
2. Go to **Applications → Applications → Create Application**
3. Choose **Regular Web Application**, name it "BackyardGarden"
4. Click **Create**

### 2. Configure Allowed URLs

In the application settings, set:

| Field | Value |
|---|---|
| Allowed Callback URLs | `http://localhost:4000/auth/auth0/callback` |
| Allowed Logout URLs | `http://localhost:4000/auth/auth0` |

For production, add your production domain alongside localhost (comma-separated).

### 3. Enable Social Connections (optional)

To enable Google login:

1. Go to **Authentication → Social**
2. Enable **Google / Gmail**
3. Auth0 provides shared dev credentials for testing; supply your own Google OAuth app credentials for production

### 4. Copy Credentials

From the **Settings** tab of your application, copy:

- **Domain** → `AUTH0_DOMAIN` (e.g. `your-tenant.auth0.com`)
- **Client ID** → `AUTH0_CLIENT_ID`
- **Client Secret** → `AUTH0_CLIENT_SECRET`

Add these to your `.env` file.

### 5. Generating a Cloak Key

The Prowl API key is encrypted at rest using AES-GCM. Generate a random 32-byte key and base64-encode it:

```bash
# In iex or any shell with Elixir available:
:crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()
```

Add the output to `.env` as `CLOAK_KEY=<output>`.

In dev, if `CLOAK_KEY` is not set, a fixed placeholder key is used automatically so the app starts without configuration.

---

## Weather Integration

The dashboard shows current conditions and a contextual planting tip powered by [OpenWeatherMap](https://openweathermap.org/api).

Set `OPENWEATHERMAP_API_KEY` in `.env`. Location format must be `City,CountryCode` (e.g. `Victoria,CA`) — province/state names are not supported by the API. The weather card is silently hidden if the key is missing.

---

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
    vault.ex                # Cloak vault for field-level encryption
    encrypted/binary.ex     # Custom Cloak.Ecto.Binary type
  backyard_garden_web/      # web layer (LiveViews, router, layouts)
    controllers/
      auth_controller.ex    # Auth0 OAuth callback + logout
    live/
      settings/
        profile_live.ex     # /settings — name, email, location, timezone
        zones_live.ex       # /settings/zones
        notifications_live.ex  # /settings/notifications
    plugs/
      require_auth.ex       # redirects unauthenticated requests to Auth0
    live/auth_hooks.ex      # on_mount hook — loads current_user into LiveView socket
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

---

## Implementation Plan

See [Plan.md](./Plan.md) for architecture decisions, data model, UI mockups, and phased implementation tasks.

Detailed task-by-task plans are in `docs/superpowers/plans/`.

---

## Deployment

Targeted at [fly.io](https://fly.io). SQLite with a persistent volume for local/dev; Postgres migration path is documented in Plan.md.

Set the following secrets before deploying:

```bash
fly secrets set AUTH0_DOMAIN=your-tenant.auth0.com
fly secrets set AUTH0_CLIENT_ID=your_client_id
fly secrets set AUTH0_CLIENT_SECRET=your_client_secret
fly secrets set CLOAK_KEY=your_base64_key
fly secrets set OPENWEATHERMAP_API_KEY=your_key   # optional
```

Then:

```bash
fly launch
fly deploy
```

Remember to add your production URLs to Auth0:
- Allowed Callback URLs: `https://your-app.fly.dev/auth/auth0/callback`
- Allowed Logout URLs: `https://your-app.fly.dev/auth/auth0`

---

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

---

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

---

## Seed Data

Seeds are user-owned — each user manages their own library. New users start with zero seeds and add them via the Add Seed page.

The app owner's initial 62 seeds were imported from CSV and can be backfilled after adding the `user_id` migration:

```elixir
# In iex -S mix
user = BackyardGarden.Users.get_user_by_email("your@email.com")
import Ecto.Query
BackyardGarden.Repo.update_all(
  from(s in BackyardGarden.Seeds.Seed, where: is_nil(s.user_id)),
  set: [user_id: user.id]
)
```

The global supplier catalog (West Coast Seeds + Metchosin Farm) is separate and powers the Add Seed browse/search workflow. Populate it by running `mix supplier.scrape`.

Original seed data sourced from:
- [Metchosin Farm Seed Library](https://metchosinfarm.ca/collections/all-seeds)
- [West Coast Seeds](https://www.westcoastseeds.com/)
