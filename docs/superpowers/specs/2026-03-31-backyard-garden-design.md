---
name: BackyardGarden Design Spec
description: Design spec for the BackyardGarden web app — planting schedules, seed tracking, iOS notifications via Prowl
type: project
---

# BackyardGarden — Design Spec

**Date:** 2026-03-31
**Status:** Approved

## Purpose

A personal web app for simon@droscher.com to manage planting schedules for the 2026 garden season and beyond. The core problem: 62 seeds across multiple brands with varying ideal planting windows, planting methods, and maturity times — too much to track in a spreadsheet while also receiving timely reminders.

## Goals

- Track all seeds and their planting windows in one place
- Know what to plant right now, what's coming up, and what's ready to harvest
- Receive iOS push notifications via Prowl (already installed)
- Run locally first, deploy to fly.io later

## Non-Goals (for now)

- Native mobile app (deferred — Flutter noted as future path)
- Multi-user collaboration
- Smart device integration

## Recommended Stack: Elixir + Phoenix

See `Plan.md` for full comparison with GOTH and Flutter options. Phoenix chosen for:
- First-class fly.io support
- LiveView for real-time UI without JavaScript
- Oban for reliable notification scheduling
- One-line Postgres migration path

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Database | SQLite → Postgres (later) | Zero-config locally; Ecto makes migration trivial |
| Auth | Auth0 (Google/Apple/email) | Avoids rolling own auth; supports social login |
| iOS notifications | Prowl API | User already has app installed; simplest integration |
| Weather | OpenWeatherMap free tier | 1k calls/day is plenty; ETS cache prevents rate limits |
| Styling | Tailwind CSS | Utility-first, mobile-responsive out of the box |

## Seed Data

Initial data imported from `data/Seed Planting 2026.csv`. Key fields:
- `Plant`, `Brand`, `Type`, `Cycle`, `Planting Method`, `Ideal Planting time`
- `Actually Planted`, `Maturity`, `Location`, `Notes`

Two seeds already planted: Spinach (Mar 27) and Swiss Chard Mix (Mar 27), both in "New garden near Raspberries".

## Core User Flows

1. **Daily check:** Open dashboard → see weather, what to plant today, upcoming events
2. **Log a planting:** My Garden → "+ Log Planting" → select seed → set date/location/notes
3. **Mark harvested:** My Garden → planted item → "Mark Harvested"
4. **Browse seeds:** Seed Library → filter/search → view detail
5. **Receive notification:** Oban job at 7am → checks planting windows → POSTs to Prowl API → iOS notification

## Open Questions (resolved)

- ~~Postgres or SQLite?~~ SQLite to start, Postgres path documented
- ~~Roll own auth or Auth0?~~ Auth0
- ~~Prowl, Pushover, or ntfy?~~ Prowl (user already has it)
- ~~Web app or Flutter?~~ Web app; Flutter noted as future option
