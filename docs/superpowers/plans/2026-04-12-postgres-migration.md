# Postgres Migration Plan

**Spec:** `docs/superpowers/specs/2026-04-12-postgres-migration-design.md`
**Branch:** `more-improvements` (or a dedicated branch)

## Context

BackyardGarden currently uses SQLite3 (`ecto_sqlite3`) in all environments. This migration switches dev and prod to Postgres while keeping SQLite for tests. Existing dev data is preserved via a one-shot Ecto-based migration task. Oban is also properly enabled as part of this work.

**Prerequisite:** Add to `.env` before starting:
```
DATABASE_URL=postgresql://username:password@localhost:5432/backyard_garden_dev
```

---

## Steps

### Step 1 — Update dependencies (`mix.exs`)
- `{:ecto_sqlite3, "~> 0.17"}` → add `only: :test` (no longer needed in dev/prod)
- `{:postgrex, "~> 0.17", optional: true}` → remove `optional: true`
- Run `mix deps.get`

### Step 2 — Update repo adapter (`lib/backyard_garden/repo.ex`)
Change adapter to conditional on `Mix.env()`:
```elixir
adapter: if(Mix.env() == :test, do: Ecto.Adapters.SQLite3, else: Ecto.Adapters.Postgres)
```

### Step 3 — Update config files

**`config/config.exs`**
- Remove the `database:` SQLite path; keep `pool_size: 5`

**`config/dev.exs`**
- Replace SQLite path config with:
```elixir
config :backyard_garden, BackyardGarden.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
```

**`config/test.exs`** — no change (keeps SQLite)

**`config/runtime.exs`**
- In the prod block: rename `DATABASE_PATH` → `DATABASE_URL`, change `database:` key to `url:`

### Step 4 — Enable Oban (`lib/backyard_garden/application.ex`)
- Uncomment the Oban supervisor entry

### Step 5 — Update Oban config (`config/config.exs`)
- Set `engine: Oban.Engines.Basic`
- Set `notifier: Oban.Notifiers.Postgres`
- Keep `:testing` mode for test env (already configured in `config/test.exs`)

### Step 6 — Create temporary SQLite repo (`lib/backyard_garden/repo_sqlite.ex`)
```elixir
defmodule BackyardGarden.RepoSQLite do
  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: Ecto.Adapters.SQLite3
end
```
Configure in `config/dev.exs` pointing at the existing dev SQLite file path.

### Step 7 — Create data migration task (`lib/mix/tasks/migrate_sqlite_to_postgres.ex`)
`Mix.Tasks.Migrate.SqliteToPostgres`:
1. Start `RepoSQLite` and `Repo` (Postgres) manually via `start_link/1`
2. Migrate tables in FK-safe order:
   - `users` → `seeds` → `supplier_products` → `garden_zones` → `plantings` → `notifications`
3. For each table: `RepoSQLite.all(Schema)`, strip Ecto metadata, `Repo.insert_all` with `on_conflict: :nothing`
4. Print row count per table on completion

Note: Reading via Ecto automatically decodes binary UUIDs and Cloak-encrypted fields — this is why we use Ecto rather than a SQL-level tool like pgloader.

### Step 8 — Clean up search queries

**`lib/backyard_garden/seeds/seeds.ex`** — `filter_by_search/2`:
```elixir
# Before
like(fragment("lower(?)", s.name), ^term) or like(fragment("lower(?)", s.brand), ^term)

# After
ilike(s.name, ^term) or ilike(s.brand, ^term)
```
Also remove `String.downcase()` from the search term prep (ilike handles case natively).

**`lib/backyard_garden/supplier_catalog.ex`** — `filter_by_search/2`: same treatment for `p.title`.

### Step 9 — Format and lint
```bash
mix format
mix credo
mix sobelow
```

---

## Verification

1. `mix deps.get` — no errors
2. `mix ecto.create` — Postgres DB created
3. `mix ecto.migrate` — all 18 migrations run cleanly on Postgres
4. `mix migrate.sqlite_to_postgres` — row counts match SQLite source
5. `mix phx.server` — app loads; verify seeds list, plantings, weather widget, Auth0 login
6. `mix test` — all tests pass (SQLite, no regressions)
7. `mix format && mix credo && mix sobelow` — all clean
8. Spot-check in browser: log in, confirm seeds and plantings are present

---

## Files Modified
| File | Change |
|------|--------|
| `mix.exs` | Dep updates |
| `lib/backyard_garden/repo.ex` | Conditional adapter |
| `config/config.exs` | Remove SQLite path, update Oban config |
| `config/dev.exs` | Switch to DATABASE_URL |
| `config/runtime.exs` | DATABASE_PATH → DATABASE_URL for prod |
| `lib/backyard_garden/application.ex` | Uncomment Oban supervisor |
| `lib/backyard_garden/seeds/seeds.ex` | ilike search |
| `lib/backyard_garden/supplier_catalog.ex` | ilike search |

## Files Created
| File | Purpose |
|------|---------|
| `lib/backyard_garden/repo_sqlite.ex` | Temporary SQLite repo for migration task |
| `lib/mix/tasks/migrate_sqlite_to_postgres.ex` | One-shot data migration task |
