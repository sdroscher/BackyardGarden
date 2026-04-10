# BackyardGarden — Implementation Plan

A mobile-responsive web app for managing planting schedules, tracking seed plantings, and receiving care reminders. Primary user: simon@droscher.com, with initial data seeded from `Seed Planting 2026.csv`.

**Stack:** Elixir + Phoenix 1.8 + Phoenix LiveView + Ecto + SQLite3 (dev) / Postgres (prod) + Tailwind CSS + Oban (background jobs)

---

## Data Model

```sql
users
  id                    UUID primary key
  email                 string unique not null
  name                  string
  timezone              string default "America/Vancouver"
  prowl_api_key         string                  -- stored plain for now; encrypt in Phase 5
  notifications_enabled boolean default true
  morning_reminder_hour integer default 8       -- hour to send morning notifications
  evening_reminder_hour integer default 18      -- hour to send evening notifications
  inserted_at           timestamp
  updated_at            timestamp

seeds
  id                    UUID primary key
  name                  string not null
  brand                 string             -- "Metchosin Farm" | "West Coast Seeds"
  type                  string             -- "Vegetable" | "Herb" | "Flower" | "Berry"
  cycle                 string             -- "Annual" | "Perennial" | "Biennial"
  planting_method       string             -- "Direct Sow" | "Seedlings"
  ideal_planting_time   string             -- human-readable, e.g. "Early Spring"
  maturity_days         integer
  sun_requirement       string             -- "full_sun" | "partial_sun" | "shade_tolerant"
  weeks_to_start_indoors integer           -- for seedling starts
  hardening_days        integer            -- days to harden off before transplanting
  source_url            string
  notes                 text
  supplier_product_id   UUID references supplier_products (nullable)
  inserted_at           timestamp
  updated_at            timestamp

supplier_products
  id                    UUID primary key
  supplier              string             -- "west_coast_seeds" | "metchosin_farm"
  shopify_product_id    string
  handle                string
  title                 string
  product_type          string
  tags                  string
  description_html      text
  url                   string
  scraped_at            timestamp
  inserted_at           timestamp
  updated_at            timestamp

garden_zones
  id                    UUID primary key
  user_id               UUID references users
  name                  string
  description           text
  sun_exposures         string             -- comma-separated: "full_sun,partial_sun"
  allowed_types         string             -- comma-separated; empty = no restriction
  allowed_cycles        string             -- comma-separated; empty = no restriction
  inserted_at           timestamp
  updated_at            timestamp

plantings
  id                    UUID primary key
  user_id               UUID references users
  seed_id               UUID references seeds
  zone_id               UUID references garden_zones (nullable)
  status                string             -- "planned" | "planted" | "harvested"
  planted_at            date
  sown_at               date               -- when seeds were sown indoors (seed starters)
  harvested_at          date
  location              string             -- free-text spot within zone
  notes                 text
  inserted_at           timestamp
  updated_at            timestamp

notifications
  id                    UUID primary key
  user_id               UUID references users
  planting_id           UUID references plantings (nullable)
  seed_id               UUID references seeds (nullable)
  type                  string             -- "plant_now" | "water" | "harvest_soon"
  message               text
  scheduled_at          timestamp
  sent_at               timestamp
  prowl_response        string
  inserted_at           timestamp
```

---

## Pages & Routes

| Route | Page | Status |
|---|---|---|
| `GET /` | Dashboard — weather, plant-now, recently planted, upcoming | ✅ |
| `GET /seeds` | Seed Library — browse/search/filter | ✅ |
| `GET /seeds/:id` | Seed Detail — info + supplier care HTML | ✅ |
| `GET /seeds/:id/edit` | Seed Edit | ✅ |
| `GET /garden` | My Garden — plantings by status, log/update | ✅ |
| `GET /calendar` | Planting Calendar — month view | ✅ |
| `GET /settings/zones` | Zone Settings — add/edit/delete zones | ✅ |
| `GET /settings/notifications` | Notification Settings — Prowl key, enable/disable | ✅ |
| `GET /settings` | User Settings — profile, location, timezone | ✅ |
| `GET /auth/callback` | Auth0 OAuth callback | ✅ |

---

## Implementation Phases

### Phases 1–5 ✅ Complete

- **Phase 1** — Seed library (browse, filter, detail pages)
- **Phase 1.5** — Supplier catalog (scrape West Coast Seeds + Metchosin Farm, fuzzy-match to seeds, display care HTML on seed detail)
- **Phase 2** — Garden & planting tracking (log plantings, update status, zones, calendar, zone recommendations)
- **Phase 3** — Dashboard & weather (OpenWeatherMap widget, ETS cache, weather-aware tips)
- **Phase 4** — Notifications (Oban workers, Prowl HTTP client, daily plant-now/harvest-soon checks, notification settings page)
- **Phase 5** — Auth & multi-user (Auth0 OAuth via ueberauth_auth0, session-based auth, route protection, Cloak-encrypted Prowl key, all data scoped to authenticated user, profile settings page, logout)

**Known issue (Phase 4):** Oban supervisor startup is commented out in `application.ex`. Oban requires a notifier/engine configuration that conflicts with SQLite in test mode. Core infrastructure (workers, jobs, config) is complete. Uncomment and configure once on Postgres (Phase 6), or when SQLite notifier config is resolved.

**Not yet implemented:** Frost warning notification (4.4) — placeholder exists in code, ready for Phase 6.

**Phase 5 notes:** Auth0 application setup (5.1) requires manual configuration in the Auth0 dashboard — set callback URL to `https://your-domain/auth/auth0/callback` and configure env vars `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, and `CLOAK_KEY` (base64-encoded 32-byte key).

### Phase 5 — Auth & Multi-user ✅

- [x] 5.1 Auth0 application setup (Google OAuth, email+password)
- [x] 5.2 Phoenix Auth0 integration (`ueberauth_auth0`)
- [x] 5.3 Protect routes behind authentication
- [x] 5.4 User settings page — location, timezone, Prowl API key (encrypt at rest with Cloak)
- [x] 5.5 Scope all garden data to authenticated user
- [x] 5.6 Add `auth0_id` and `location` fields to `users` table

### Phase 6 — Deployment

- [ ] 6.1 Dockerfile (multi-stage, minimal image)
- [ ] 6.2 `fly.toml` — SQLite persistent volume
- [ ] 6.3 Runtime config (env vars for Auth0 credentials, secrets)
- [ ] 6.4 fly.io deploy and smoke test
- [ ] 6.5 Uncomment Oban supervisor (works out-of-the-box on Postgres)
- [ ] 6.6 (Optional) Postgres migration — swap `ecto_sqlite3` for `postgrex`, run `mix ecto.migrate`

---

## Future Considerations

- **Frost warning notification** — weather-triggered, placeholder in DailyCheckWorker
- **Supplier catalog refresh** — Oban job to re-scrape weekly and re-run fuzzy matching
- **Seed sun_requirement enrichment** — currently left blank; admin edit form allows filling in as needed
- **Flutter app** — Phoenix backend can expose a JSON API with minimal changes; Auth0 already supports Flutter SDKs
- **Plant growth tracking** — add photos and measurements to plantings table
- **Smart device integration** — webhooks from soil moisture sensors → Prowl notifications

---

## Key Dependencies

| Library | Purpose |
|---|---|
| `phoenix` / `phoenix_live_view` | Web framework + real-time UI |
| `ecto_sqlite3` | SQLite adapter (dev/local) |
| `postgrex` | Postgres adapter (prod/fly.io, Phase 6) |
| `oban` | Background jobs / notification scheduler |
| `ueberauth_auth0` | Auth0 OAuth (Phase 5) |
| `cloak_ecto` | Encrypted fields — Prowl API key (Phase 5) |
| `tailwind` | CSS framework |
| `req` | HTTP client (OpenWeatherMap + Prowl API) |
| `tzdata` | Timezone database for local date calculations |
| `nimble_csv` | CSV parsing (seed import) |
