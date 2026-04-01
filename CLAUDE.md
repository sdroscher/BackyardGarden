# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BackyardGarden is a Phoenix LiveView web app for managing planting schedules. Phase 1 (seed library with browsing, filtering, and detail pages) is complete. Future phases add planting schedules, garden zones, weather integration, iOS notifications (Prowl), and Auth0 login.

**Stack:** Elixir + Phoenix 1.8 + Phoenix LiveView + Ecto + SQLite3 + Tailwind CSS

## Commands

```bash
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
- `BackyardGarden.Seeds` — context module with `list_seeds/1` (accepts filter map), `get_seed!/1`, `create_seed/1`, and distinct list helpers

**Web layer:**
- `Seeds.IndexLive` — live browse/filter page at `/seeds`; handles `"filter"` events, rebuilds query in real-time
- `Seeds.ShowLive` — seed detail page at `/seeds/:id`
- Router: `GET /` → PageController, `/seeds` → IndexLive, `/seeds/:id` → ShowLive

**Seed data:** 62 seeds imported from CSV via `priv/repo/seeds.exs` using NimbleCSV.

## Key Conventions

- **Credo strict mode is on.** `TODO` comments fail the build (exit_status 2). Max line length: 120.
- **`@moduledoc` must come before `use`** in LiveView modules (enforced by credo).
- **SQL wildcard escaping:** `%` and `_` in search strings must be escaped before LIKE queries — see `Seeds.filter_by_search/2`.
- **Binary IDs (UUIDs)** are the default primary key type — set in generator config.
- **UTC timestamps** are the default.
- Tests use `async: true` with the SQL sandbox for LiveView tests.

## Code Quality

- Fix the code, not the tests (unless tests are incorrect)
- Use descriptive variable and function names
- Ensure compliance with linting rules (credo, sobelow)
- Add tests for new features and bug fixes

## Documentation

- Add comments for complex logic, but prefer clear code over comments when possible
- Comments should explain "why", not "what" — the code should be self-explanatory about "what" it does
- Prefer comments to be at the function level rather than inline, unless explaining a non-obvious line of code
- If a block of code needs a comment, consider if it can be refactored into a well-named function instead, which may eliminate the need for the comment altogether
- Keep README.md up to date with any architectural changes or new features
  - this includes quick start instructions, env variable table, and any new dependencies or setup steps
- Mark any completed tasks/phases in Plan.md and update the project roadmap as needed

