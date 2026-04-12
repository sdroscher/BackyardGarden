# Postgres Migration Design

**Date:** 2026-04-12

## Context

BackyardGarden currently uses SQLite3 via `ecto_sqlite3`. The app is approaching deployment (Phase 6), and Postgres is the target production database. SQLite has also been blocking Oban from running properly. This migration switches dev and prod to Postgres while keeping SQLite for tests (tests are isolated and don't hit the real DB). Existing dev data must be preserved via a one-shot migration task.

## Goals

- Dev and prod use Postgres
- Tests keep SQLite (no change to test behaviour)
- Existing dev data migrated from SQLite to Postgres safely
- Oban properly enabled now that Postgres is available
- Search queries cleaned up to use Postgres-native `ilike`

## Architecture

### 1. Adapter Strategy

The repo module sets the adapter conditionally at compile time:

```elixir
defmodule BackyardGarden.Repo do
  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: if(Mix.env() == :test, do: Ecto.Adapters.SQLite3, else: Ecto.Adapters.Postgres)
end
```

This keeps the single-repo pattern while cleanly splitting adapters by environment.

### 2. Dependencies (`mix.exs`)

- `ecto_sqlite3`: move to `only: :test` (no longer needed in dev/prod)
- `postgrex`: remove `optional: true` (promote to a normal dep)

### 3. Configuration

| File | Change |
|------|--------|
| `config/config.exs` | Remove SQLite database path; keep pool_size |
| `config/dev.exs` | Switch to `url: System.get_env("DATABASE_URL")` |
| `config/test.exs` | No change — keeps SQLite file path |
| `config/runtime.exs` | Update prod block to use `DATABASE_URL` env var (already structured for this) |

`.env` (dev):
```
DATABASE_URL=postgresql://username:password@localhost:5432/backyard_garden_dev
```

### 4. Data Migration Task

A one-shot mix task at `lib/mix/tasks/migrate_sqlite_to_postgres.ex`:

- Starts a separate `RepoSQLite` module (pointing at the SQLite file) alongside the main Postgres `Repo`
- Migrates tables in FK-safe order: `users` → `seeds` → `supplier_products` → `garden_zones` → `plantings` → `notifications`
- Reads via Ecto (handles binary UUID decoding and Cloak field decryption automatically)
- Inserts via `Repo.insert_all` with `on_conflict: :nothing` (idempotent, safe to re-run)
- Prints row counts per table on completion

**Why Ecto and not pgloader:** `ecto_sqlite3` stores UUIDs as 16-byte binary blobs. SQL-level tools can't translate these correctly. Reading through Ecto decodes them to proper UUID strings automatically.

### 5. Oban

With Postgres available, Oban can be fully enabled:

- Uncomment Oban supervisor in `lib/backyard_garden/application.ex`
- Update `config/config.exs` Oban config: use `engine: Oban.Engines.Basic` and `notifier: Oban.Notifiers.Postgres`
- Test config stays in `:testing` mode (already configured)

### 6. Search Cleanup

Replace `like(fragment("lower(?)", field), ^term)` with `ilike(field, ^term)` in:

- `lib/backyard_garden/seeds/seeds.ex` — `filter_by_search/2`
- `lib/backyard_garden/supplier_catalog.ex` — `filter_by_search/2`

The `coalesce` fragment in `lib/backyard_garden/dashboard.ex` works fine in Postgres — no change needed.

## Files to Modify

- `mix.exs`
- `lib/backyard_garden/repo.ex`
- `config/config.exs`
- `config/dev.exs`
- `config/runtime.exs`
- `lib/backyard_garden/application.ex`
- `lib/backyard_garden/seeds/seeds.ex`
- `lib/backyard_garden/supplier_catalog.ex`

## Files to Create

- `lib/mix/tasks/migrate_sqlite_to_postgres.ex` — one-shot data migration task
- `lib/backyard_garden/repo_sqlite.ex` — temporary SQLite repo used only by the migration task

## Verification

1. Add `DATABASE_URL` to `.env`
2. `mix deps.get` — confirm postgrex fetched, ecto_sqlite3 still present for test
3. `mix ecto.create` — creates Postgres DB
4. `mix ecto.migrate` — runs all 18 migrations against Postgres
5. `mix migrate.sqlite_to_postgres` — migrates data; confirm row counts match SQLite source
6. `mix phx.server` — verify app loads, seeds list works, plantings work, weather works
7. `mix test` — all tests pass (still on SQLite)
8. Spot-check: log in via Auth0, verify your seeds and plantings are present
