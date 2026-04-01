# BackyardGarden

A mobile-responsive web app for managing planting schedules, tracking seed plantings, and receiving iOS reminders via Prowl.

Built with **Elixir + Phoenix LiveView**, deployed to **fly.io**.

## Features

**Phase 1 — Complete**
- Seed library with live search and filtering (62 seeds)
- Seed detail pages

**Phase 2+ — Planned**
- Planting schedule tracking — planned, planted, harvested
- Garden zone recommendations based on plant type, cycle, and sun requirements
- Monthly planting calendar with ideal window overlays
- Weather-aware planting tips via OpenWeatherMap
- iOS push notifications via [Prowl](https://www.prowlapp.com/)
- Auth0 login (Google, Apple, email)

## Getting Started

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+ (install via [asdf](https://asdf-vm.com/))
- Phoenix 1.8+

```bash
asdf plugin add erlang && asdf install erlang 27.2
asdf plugin add elixir && asdf install elixir 1.18.2-otp-27
mix archive.install hex phx_new
```

### Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs   # imports seeds from Seed Planting 2026.csv
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

### Tests

```bash
mix test
```

## Project Structure

```
lib/
  backyard_garden/          # business logic (contexts)
    seeds/                  # Seeds context + schema
    garden/                 # Plantings, Zones contexts (Phase 2)
  backyard_garden_web/      # web layer (LiveViews, router, layouts)
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

## Seed Data

Initial seed data sourced from:
- [Metchosin Farm Seed Library](https://metchosinfarm.ca/collections/all-seeds)
- [West Coast Seeds](https://www.westcoastseeds.com/)
