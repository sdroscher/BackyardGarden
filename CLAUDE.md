# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BackyardGarden is a Phoenix LiveView web app for managing planting schedules. Phase 1 (seed library with browsing, filtering, and detail pages) is complete. Future phases add planting schedules, garden zones, weather integration, iOS notifications (Prowl), and Auth0 login.

**Progress:** Phase 1 ✅, Phase 1.5 (Supplier Catalog) ✅, Phase 2 (Garden & Plantings) ✅, Phase 3 (Dashboard & Weather) ✅, Phase 4 (Notifications) ✅, Phase 5 (Auth0 + multi-user) ✅, Phase 5.5 (Postgres migration) ✅. Phase 6 (Deployment) coming next.

**Stack:** Elixir + Phoenix 1.8 + Phoenix LiveView + Ecto + Postgres (dev/prod) / SQLite3 (test) + Tailwind CSS

## Commands

```bash
# Debug interactively (safe for dev DB queries)
iex -S mix

# Start dev server
mix phx.server

# First-time setup (deps, DB, migrate, assets)
mix setup

# Tests (auto-creates and migrates test DB)
mix test

# Single test file or line
mix test test/backyard_garden/seeds_test.exs
mix test test/backyard_garden/seeds_test.exs:12

# Linting
mix credo        # strict mode — all checks must pass
mix sobelow      # security scan
mix format       # code formatter

# Pre-commit check (compile with warnings-as-errors + format + deps + tests)
mix precommit
```

## Architecture

Phoenix context pattern: business logic lives in `lib/backyard_garden/` contexts; web layer in `lib/backyard_garden_web/`.

**Data layer:**
- `BackyardGarden.Seeds.Seed` — Ecto schema (UUID primary keys, fields: name, brand, type, cycle, planting_method, ideal_planting_time, maturity_days, sun_requirement, source_url, notes)
- `BackyardGarden.Seeds` — context module with `list_seeds(user_id, filters \\ %{})`, `get_seed!/1`, `create_seed_for_user(user_id, attrs)`, and distinct list helpers (all scoped by user_id)
- `BackyardGarden.Users` — User schema (email, timezone, prowl_api_key, notifications_enabled) and CRUD (Phase 4)
- `BackyardGarden.Notifications` — Notification schema (type, message, scheduled_at, sent_at) and delivery tracking (Phase 4)
- `BackyardGarden.Plantings` — context for plantings (CRUD + `list_plantings_for_month/1`)
- `BackyardGarden.GardenZones` — context for zones (CRUD + `recommend_zones/2` scoring engine); scoped to user_id
- `BackyardGarden.PlantingCalendar` — parses `ideal_planting_time` text → list of `{start_month, end_month}` tuples (supports comma-separated multi-window e.g. `"Autumn,Early Spring"`); returns `[]` for unrecognised input; builds week grids
- `BackyardGarden.Dashboard` — query functions for the dashboard (plant_now_seeds, recently_planted, upcoming_schedule)
- `BackyardGarden.Weather` / `Weather.Client` / `Weather.Cache` / `Weather.Tips` — weather facade, HTTP client, ETS cache, and contextual tip generation

**Web layer:**
- `Dashboard.IndexLive` — dashboard page at `/`; bento grid with Plant Now quick-log, Recently Planted, Coming Up, weather card
- `BackyardGardenWeb.NavHooks` — `on_mount` hook assigning `current_path` for active nav highlighting
- `Seeds.IndexLive` — live browse/filter page at `/seeds`; handles `"filter"` events, rebuilds query in real-time
- `Seeds.ShowLive` — seed detail page at `/seeds/:id`
- `Seeds.EditLive` — seed edit form at `/seeds/:id/edit`
- `Garden.IndexLive` — My Garden page at `/garden`; log plantings, update status, zone recommendations
- `Calendar.IndexLive` — Planting calendar at `/calendar`; month grid with planted/harvest/ideal markers
- `Settings.ZonesLive` — Zone settings at `/settings/zones`; add/edit/delete zones
- `Settings.ProfileLive` — Profile settings at `/settings`; name, email, location, timezone
- `Settings.NotificationsLive` — Notification settings at `/settings/notifications`
- `BackyardGardenWeb.AuthHooks` — `on_mount` hook that loads `current_user` from session into all LiveView sockets; redirects to `/auth/auth0` if unauthenticated
- `BackyardGardenWeb.Plugs.RequireAuth` — plug that redirects unauthenticated controller requests to `/auth/auth0`
- Router: all app routes protected; unauthenticated scope covers `/auth/auth0`, `/auth/auth0/callback`, `/auth/logout` only

**Seed data:** Seeds are user-owned; new users start with 0 seeds. `priv/repo/seeds.exs` is kept for historical reference only — it no longer works because `user_id` is required. Use the iex backfill documented in README.md.

## Key Conventions

- **Always backup before destructive DB operations** — Before running `mix ecto.reset`, `mix ecto.drop`, or deleting database files, first create a backup: `cp priv/repo/backyard_garden_dev.db priv/repo/backyard_garden_dev.db.backup`. Never delete data without a backup in place.
- **Phase completion checklist** — Before finishing a phase, run `git status` and ensure all files are committed. Update `Plan.md` (mark items complete) and `README.md` (document new features). No uncommitted files allowed.
- **`mix run -e` targets the dev DB** — never use for throwaway queries; use `iex -S mix` instead.
- **Env vars loaded via dotenvy** — `.env` is auto-loaded in dev via `config/runtime.exs`; never put secrets in committed config files. Weather: `OPENWEATHERMAP_API_KEY=...`, location: `DEFAULT_LOCATION=Victoria,CA` (format: `City,CountryCode`). Prowl notifications: set `PROWL_API_KEY` in `.env` OR configure via `/settings/notifications` page (stored in database).
- **`GardenZones.recommend_zones/1` returns plain structs** — no `.score` field; all returned zones are already filtered to compatible matches, sorted by quality.
- **Local date from timezone** — `DateTime.utc_now() |> DateTime.shift_zone!(timezone) |> DateTime.to_date()` is the correct pattern throughout the app (tzdata is already a dep). Never use `Date.utc_today()` where a local date is needed.
- **Migration timestamp collisions** — generating two migrations in the same second produces identical filenames; rename the second file to increment the timestamp by 1 (e.g. `...012321` → `...012322`).
- **OpenWeatherMap wind speed** — returned in m/s under `["wind", "speed"]`; multiply by 3.6 for km/h. Guard with `|| 0` for nil safety.
- **No early return in Elixir** — use `with false <- condition` (or pattern-match on `:ok`/`:error`) to bail out of a function with a specific value. `return/1` does not exist.
- **Planting date field is `planted_at`** — the `Planting` schema field is `:planted_at`, not `:date_planted`.
- **Credo strict mode is on.** `TODO` comments fail the build (exit_status 2). Max line length: 120.
- **Oban is fully enabled** — Oban supervisor runs in dev/prod on Postgres. Tests use `notifier: Oban.Notifiers.PG` (in `config/test.exs`) to avoid Postgrex connection errors; `notifier: Oban.Notifiers.Postgres` is the prod/dev notifier (in `config/config.exs`).
- **`@moduledoc` must come before `use`** in LiveView modules (enforced by credo).
- **SQL wildcard escaping:** `%` and `_` in search strings must be escaped before LIKE queries — see `Seeds.filter_by_search/2`.
- **Binary IDs (UUIDs)** are the default primary key type — set in generator config.
- **UTC timestamps** are the default.
- **LiveView/controller tests use `async: false`** — SQLite only allows one concurrent writer; `async: true` causes intermittent "Database busy" failures. Only pure computation tests (no DB) may use `async: true`.
- **Forms use `<.input field={@form[:x]} label="Label" />`** — never wrap in a manual `<label>`; `<.input>` renders its own label. Hint text goes in a `<p>` sibling below the component.
- **`to_form/2` needs `as:` when schema name ≠ param key** — e.g. `GardenZone` changeset needs `to_form(changeset, as: "zone")` so params arrive as `zone[name]` not `garden_zone[name]`.
- **Forms need both `phx-submit` and `phx-change`** — the change handler rebuilds the changeset with `|> Map.put(:action, :validate)` to show inline errors while typing.
- **Test fixture helpers: omit default args** — write `defp fixture(attrs)` not `defp fixture(attrs \\ %{})` unless a call site actually omits the argument. Unused defaults produce compiler warnings.
- **SQLite async test flakiness** — `async: true` tests can intermittently fail with "Database busy" under high concurrency. Re-run to confirm; it is not a test bug.
- **Form conversion required** — Always use `to_form(changeset)` before passing to `.input` components. Don't pass changesets directly; `Access.get/3` will fail on the changeset struct.
- **Logger.configure timing** — Must call `Logger.configure(level: :info)` BEFORE `Mix.Task.run("app.start")`, not after. Ecto configures at startup, so log level needs to be set first.
- **Supplier scraper headers** — Must match modern Chrome headers (sec-ch-ua, sec-fetch-*, upgrade-insecure-requests) to avoid Cloudflare WAF blocks. Disable Req retries with `retry: false` and add delays (2-5s) between requests to respect rate limits.
- **Zone matching gotcha** — Zone editor accepts free-form text for allowed_types/cycles/sun_exposures, but matching logic requires exact string matches. Document examples or use dropdowns for UX clarity.
- **Ueberauth v0.10 — use `plug Ueberauth`, not `use Ueberauth`** — `use Ueberauth` was removed; add `plug Ueberauth` to the controller and define a no-op `request/2` action (ueberauth halts the conn before it's reached).
- **Auth callback must not redirect to protected routes on failure** — redirecting to `"/"` on auth failure creates an Auth0 ↔ app redirect loop (Auth0 caches the session and immediately bounces back). On failure, redirect to `/auth/auth0` or render a response directly.
- **Logout route must be GET** — browser `<a>` tags issue GET requests; using `delete` for a logout route silently 404s when clicked from the nav.
- **Backfill `user_id` after adding auth scoping** — when a `user_id` FK is added to an existing table, existing rows have `NULL` and won't appear in any user's scoped queries. Backfill via `Repo.update_all(Schema, set: [user_id: id])` in iex after migrating.
- **`phx-value-*` is a stale-value trap** — `phx-value-foo={@assign}` sends the server-side assign at render time, NOT the current input value. For `phx-keyup` on plain inputs, omit `phx-value-*` and read `%{"value" => val}` in the handler instead.
- **Testing mount-time redirects** — when `push_navigate` fires in `mount/3` (e.g. ownership check), `live(conn, path)` returns `{:error, {:live_redirect, %{to: "/path", flash: flash}}}`. Pattern match on that; don't expect `{:ok, view, html}`.
- **Hidden inputs for pre-filled non-visible fields** — if a field is set in a changeset via pre-fill but has no visible `<.input>`, it is dropped on submit. Add `<input type="hidden" name="schema[field]" value={@form[:field].value} />` to preserve it.
- **Cancel in-flight async Tasks before re-spawning** — call `Task.shutdown(socket.assigns.fetch_task, :brutal_kill)` before spawning a replacement task, otherwise both results arrive and the first one wins.
- **`ilike` is Postgres-only** — SQLite does not support `ilike`. Use `like(fragment("lower(?)", field), ^String.downcase(term))` for searches that need to work on both adapters (dev uses Postgres, tests use SQLite).
- **SQLite does not support `ALTER COLUMN`** — migrations that use `modify` must guard against SQLite: `unless BackyardGarden.Repo.__adapter__() == Ecto.Adapters.SQLite3 do ... end`. Without the guard, `mix test` will fail when the migration runs against the test SQLite DB.
- **Large integer columns need `bigint` in Postgres** — `:integer` maps to int4 (max ~2.1B). Shopify product IDs exceed this; use `field :shopify_product_id, :id` in the schema (Ecto `:id` = int8) and `add :col, :bigint` in migrations.
- **Dev/prod use Postgres; tests use SQLite** — `Repo.__adapter__()` returns the correct adapter per `Mix.env()`. DB URL for dev comes from `DATABASE_URL` in `.env`, loaded by dotenvy in `config/runtime.exs` (not `dev.exs`, since `dev.exs` is evaluated before dotenvy runs).

## Code Quality

- **Always run `mix format` after making changes** — keeps diffs clean and prevents credo line-length violations from unformatted code
- Fix the code, not the tests (unless tests are incorrect)
- Use descriptive variable and function names
- Ensure compliance with linting rules (credo, sobelow)
- Add tests for new features and bug fixes
- **Write a failing test before fixing any bug** — confirm it fails, apply the fix, confirm it passes

## UI Style Guide

All new pages and components must follow the Botanical & Lush design language established in the frontend redesign. Full spec: `docs/superpowers/specs/2026-04-01-frontend-redesign-design.md`.

### Colors

| Role | Tailwind arbitrary / hex | Usage |
|---|---|---|
| Nav background | `#1a3a2a → #2d6a4f` gradient | Header only |
| Page background | `bg-[#f0fdf4]` | `<body>`, page wrappers |
| Cards | `bg-white border border-[#bbf7d0] rounded-xl` | All content cards |
| Card hover | `hover:bg-[#f0fdf4]` | Table rows, clickable cards |
| Primary button | `bg-[#2d6a4f] text-white rounded-lg` | CTAs, confirm actions |
| Text — headings | `text-[#14532d]` | Page titles, seed names |
| Text — secondary | `text-[#6b7280]` | Labels, metadata |
| Text — body | `text-[#374151]` | Paragraphs, descriptions |
| Section labels | `text-[#52b788] uppercase tracking-wide text-xs font-semibold` | Card section headers |
| Accent border | `border-l-4 border-l-[#2d6a4f]` | Growing guide, highlighted cards |

### Type Badges

Seed type badges use color-coded pill styles. Apply consistently wherever a seed type is shown:

| Type | Classes |
|---|---|
| Vegetable | `text-[#16a34a] bg-[#dcfce7]` |
| Herb | `text-[#7c3aed] bg-[#ede9fe]` |
| Flower | `text-[#d97706] bg-[#fef3c7]` |
| Berry | `text-[#db2777] bg-[#fce7f3]` |

Badge base classes: `text-xs font-medium px-2.5 py-0.5 rounded-full`

### Layout

- Max content width: `max-w-5xl mx-auto px-4`
- Page padding: `py-8`
- Card gap: `gap-4` or `space-y-4`
- Two-column detail layouts: `grid grid-cols-1 md:grid-cols-[1fr_1.6fr] gap-4`
- Responsive card grid (mobile): `grid grid-cols-2 gap-3`

### Navigation

The `Layouts.app/1` component in `lib/backyard_garden_web/components/layouts.ex` provides the standard nav. Use it for all new pages — do not create alternate nav styles.

New nav links go in the existing `<div class="flex items-center gap-6 ...">` block. Use `~p"/route"` verified routes.

## Documentation

- Add comments for complex logic, but prefer clear code over comments when possible
- Comments should explain "why", not "what" — the code should be self-explanatory about "what" it does
- Prefer comments to be at the function level rather than inline, unless explaining a non-obvious line of code
- If a block of code needs a comment, consider if it can be refactored into a well-named function instead, which may eliminate the need for the comment altogether
- **Update README.md at the end of every feature or phase** — document new capabilities, update env var tables, fix any setup instructions affected by the change
- Keep README.md up to date with any architectural changes or new features
  - this includes quick start instructions, env variable table, and any new dependencies or setup steps
- Mark any completed tasks/phases in Plan.md and update the project roadmap as needed

## Fly.io Deployment

- **Fly.io private network requires IPv6 sockets** — set `ECTO_IPV6=true` in `fly.toml [env]` and add `socket_options: maybe_ipv6` to the Repo config in `runtime.exs`. Without this, all `.internal` and `.flycast` connections fail with `:nxdomain` because Erlang defaults to IPv4 sockets on an IPv6-only network.
- **`mix phx.gen.release` doesn't set executable bits** — generated `rel/overlays/bin/server` and `rel/overlays/bin/migrate` are created as `644`. Run `chmod +x rel/overlays/bin/server rel/overlays/bin/migrate` and commit the mode change.
- **`mix compile` before `mix assets.deploy` in Dockerfile** — Phoenix 1.8 colocated hooks generate a `phoenix-colocated/backyard_garden` package during `mix compile`. The Dockerfile must compile the app first or esbuild can't resolve the import.
- **512MB minimum for BEAM on Fly.io** — 256MB causes OOM kills on startup. Set `memory = "512mb"` in `[[vm]]`.
- **`force_ssl` breaks Fly health checks** — Fly's internal HTTP health checks don't include `x-forwarded-proto`, so `force_ssl` returns 301, marking the machine critical. Remove `[[http_service.checks]]` or use a dedicated `/health` path excluded from SSL.
- **`flyctl` not `fly` in GitHub Actions** — the `superfly/flyctl-actions/setup-flyctl@master` action installs the binary as `flyctl`, not `fly`.

## UI / Frontend Gotchas

- **daisyUI `prefersdark: true` conflicts with fixed light design** — setting `prefersdark: true` on the dark daisyUI theme makes `.input`, `.select`, `.textarea` get dark backgrounds via `prefers-color-scheme: dark` even when `bg-[...]`/`text-[...]` classes on `<body>` are light. Set `prefersdark: false` so dark theme only activates via explicit `data-theme="dark"`.
- **Set background on `<html>` to prevent dark overscroll on mobile** — `<body>` alone is insufficient; the `<html>` element also needs `bg-[#fafdf9]` in `root.html.heex` or overscrolling reveals the dark browser default on iOS/Android.
- **Mobile hamburger menus use `JS.toggle`** — `phx-click={JS.toggle(to: "#mobile-menu")}` in heex templates is the Phoenix LiveView approach; no custom JS hooks needed. Pair with `hidden md:flex` on the desktop nav and `hidden md:hidden` on the mobile dropdown.
- **`attr` on `defp` components requires `slot` declaration** — once you add any `attr` macro to a `defp` function component, Phoenix requires all slots to be declared too (e.g. `slot :inner_block, required: true`), or you get "undefined slot" compiler warnings.
- **CSS grid blockifies inline elements for full-width tap targets** — `grid grid-cols-1` on a container automatically promotes `<a>` and other inline children to block-level full-width, avoiding the need to add `block w-full` to every child individually.
- **`phx-value-value` is broken on `<button>`** — `value` is an HTML IDL attribute; the LiveView JS reads the element's `.value` property (empty string) instead of the `phx-value-value` attribute content. Use any other suffix: `phx-value-pill`, `phx-value-id`, etc.
- **`render_click(view, event, params)` bypasses button attributes** — params are sent directly to the handler, so tests pass even when `phx-value-*` attributes on the actual button are wrong. Use `element(...) |> render_click()` to catch attribute mismatches.
