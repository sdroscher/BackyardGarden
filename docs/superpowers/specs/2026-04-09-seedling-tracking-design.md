# Seedling Tracking Design

**Date:** 2026-04-09
**Status:** Approved

## Overview

Seeds with `planting_method = "Seedlings"` (e.g. tomatoes, peppers, basil) must be started indoors in seed trays before they can be transplanted into the garden. They go through three stages before reaching the garden: sown indoors → hardening off → transplanted. This feature adds full tracking for that lifecycle, including calculated date guidance and notifications at each stage.

## Scope

- Two new fields on the `Seed` schema (`weeks_to_start_indoors`, `hardening_days`)
- Two new planting statuses (`sown`, `hardening`) and one new date field (`sown_at`)
- Garden page updated with "In Trays" and "Hardening" sections
- Log Planting form adapts when a Seedlings-method seed is selected
- Seed edit page gets the new fields and an entry point from the show page
- `planting_method` converted to a dropdown on the seed edit form
- Five new notification types
- `HourlyCheckWorker` replaces `DailyCheckWorker` with user-configurable reminder times
- `morning_reminder_hour` and `evening_reminder_hour` added to User schema and Settings page

## Data Model

### Seed schema (`lib/backyard_garden/seeds/seed.ex`)

Two new optional integer fields:

| Field | Type | Description |
|---|---|---|
| `weeks_to_start_indoors` | integer, nullable | How many weeks before transplant to sow seeds indoors (e.g. 8 for tomatoes) |
| `hardening_days` | integer, nullable | How many days of outdoor exposure before transplanting (e.g. 7) |

Both are advisory — only relevant when `planting_method = "Seedlings"`. No validation required.

### Planting schema (`lib/backyard_garden/plantings/planting.ex`)

One new field and two new status values:

| Change | Detail |
|---|---|
| `sown_at` (date, nullable) | The date seeds went into trays |
| Status `"sown"` | Seeds are in trays growing indoors |
| Status `"hardening"` | Seedlings are being exposed to outdoor conditions |

`@valid_statuses` becomes `~w(planned sown hardening planted harvested)`.

`planted_at` retains its existing meaning ("in the ground") — for seedlings this is the actual transplant date. For a seedling in `"planned"` status, `planted_at` stores the **target transplant date**, which drives sow date calculation. This is consistent with how `planted_at` works today for direct-sow planned plantings.

### Calculated dates (never stored)

All derived dates are computed on the fly from stored fields and seed settings:

| Derived date | Formula |
|---|---|
| Sow date | `planted_at − (weeks_to_start_indoors × 7) − hardening_days` |
| Hardening start | `sown_at + (weeks_to_start_indoors × 7)` |
| Projected transplant | `sown_at + (weeks_to_start_indoors × 7) + hardening_days` |

If `weeks_to_start_indoors`, `hardening_days`, or the required anchor date (`planted_at` for planned, `sown_at` for sown/hardening) is nil, derived dates are nil and notifications for that planting are silently skipped.

### User schema (`lib/backyard_garden/users/user.ex`)

Two new integer fields for configurable notification times:

| Field | Type | Default | Description |
|---|---|---|---|
| `morning_reminder_hour` | integer | 8 | Hour (0–23) to send morning reminders in user's timezone |
| `evening_reminder_hour` | integer | 18 | Hour (0–23) to send evening reminders in user's timezone |

## Status Lifecycle

```
planned ──→ sown ──→ hardening ──→ planted ──→ harvested
  (Mark Sown)  (Mark Hardening)  (Mark Transplanted)  (Mark Harvested)
```

Direct-sow plantings skip `sown` and `hardening` entirely — their flow is unchanged: `planned → planted → harvested`.

The UI determines which action buttons to show based on both `status` and `seed.planting_method`. Only seedling-method seeds ever appear in the "In Trays" or "Hardening" sections.

## Garden Page UI

Five sections, in order:

| Section | Header colour | Query | Action button |
|---|---|---|---|
| Planned | Grey | `status = "planned"` | "Mark Planted" (direct sow) or "Mark Sown" (seedling) |
| In Trays | Purple | `status = "sown"` | "Mark Hardening" |
| Hardening | Amber | `status = "hardening"` | "Mark Transplanted" |
| Planted | Green | `status = "planted"` | "Mark Harvested" |
| Harvested | Violet | `status = "harvested"` | Edit only |

**Planned section** — seedling plantings show a purple "🌱 Seedling" badge and display their calculated sow date ("Sow by Mar 27") in place of the seed's `ideal_planting_time`.

**In Trays section** — each row shows: sow date, projected hardening start date (highlighted in amber when approaching), projected transplant date.

**Hardening section** — each row shows: hardening start date, transplant deadline (highlighted in green when approaching).

Sections with zero items are still rendered (showing the empty-state message) so the page structure is consistent.

## Log Planting Form

When a seed with `planting_method = "Seedlings"` is selected:

- The status dropdown gains two new options: "In Trays" (`sown`) and "Hardening" (`hardening`)
- The date field label and placeholder adapt to the selected status:
  - Planned → "Target transplant date" (stored in `planted_at`)
  - In Trays → "Date sown" (stored in `sown_at`); defaults to today
  - Hardening → no primary date field shown (dates are computed)
  - Planted/Harvested → unchanged
- A purple info panel below the date field shows the derived dates so the user can verify the calculation

For non-seedling seeds the form is unchanged.

## Edit Planting Form

The existing edit form gains the same expanded status dropdown as the log form when the planting's seed has `planting_method = "Seedlings"`. Date field behaviour differs slightly from the log form: the edit form always shows `sown_at` as an editable field for `sown` and `hardening` status plantings (so the user can correct a wrong date), rather than hiding it. The info panel showing derived dates is shown for all seedling statuses.

## Seed Edit Page

The `Seeds.EditLive` page already exists at `/seeds/:id/edit` but has no entry point. Changes:

1. Add an "Edit" button to `show_live.html.heex`
2. Convert `planting_method` from a free-text input to a dropdown: Direct Sow / Seedlings / Transplant
3. Add `weeks_to_start_indoors` (number input) and `hardening_days` (number input) to the edit form, shown only when `planting_method = "Seedlings"`

## Notifications

### New notification types

Added to `@valid_types` in `Notification` schema:

| Type | Trigger | Message example |
|---|---|---|
| `sow_now` | Morning run, `status = "planned"`, today = sow date | "Time to sow your Tomatoes indoors — target transplant is May 15" |
| `start_hardening` | Morning run, `status = "sown"`, today = hardening start | "Time to start hardening your Tomatoes — transplant in 7 days" |
| `hardening_morning` | Morning run, `status = "hardening"` | "Time to take your Tomatoes outside for today's hardening" |
| `hardening_evening` | Evening run, `status = "hardening"` | "Time to bring your Tomatoes inside for the night" |
| `hardening_weather_warning` | Morning run, `status = "hardening"`, bad weather forecast | "Keep your Tomatoes inside today — heavy rain / high wind / heat expected" |

### HourlyCheckWorker

Replaces `DailyCheckWorker` (which is deleted). Runs at the top of every hour via Oban cron. For each user:

1. Converts current UTC time to the user's timezone
2. If `current_hour == morning_reminder_hour`: runs all morning checks
3. If `current_hour == evening_reminder_hour`: runs all evening checks

**Morning checks (in order):**
- `sow_now` — seedling plantings with `status = "planned"` where sow date = today
- `start_hardening` — seedling plantings with `status = "sown"` where hardening start = today
- `hardening_weather_warning` — if any plantings have `status = "hardening"`, fetch today's weather forecast; send warning if rain, wind > threshold, or temperature > 30°C
- `hardening_morning` — all plantings with `status = "hardening"` (skipped if a weather warning was sent)
- `plant_now` — existing check, unchanged
- `harvest_soon` — existing check, unchanged

**Evening checks:**
- `hardening_evening` — all plantings with `status = "hardening"`

Duplicate prevention follows the existing pattern: no notification of the same type for the same planting within 24 hours.

### Weather check for hardening warnings

Reuses the existing `Weather.Client` / `Weather.Cache` infrastructure. Checks today's forecast (OpenWeatherMap API returns daily forecast data in the standard response). Warning conditions:
- Rain: precipitation forecast > 2 mm (filters out light drizzle)
- Wind: wind speed > 40 km/h
- Heat: temperature > 30°C

If the user's weather data is unavailable (API error, no location set), the warning check is silently skipped.

## Settings Page (`/settings/notifications`)

Adds two new fields to the existing notifications settings form:

- **Morning reminder time** — hour dropdown (6 AM – 11 AM, default 8 AM)
- **Evening reminder time** — hour dropdown (4 PM – 10 PM, default 6 PM)

## Migrations Required

1. `add_seedling_fields_to_seeds` — adds `weeks_to_start_indoors` and `hardening_days` (integers, nullable)
2. `add_seedling_fields_to_plantings` — adds `sown_at` (date, nullable)
3. `add_reminder_hours_to_users` — adds `morning_reminder_hour` (integer, default 8) and `evening_reminder_hour` (integer, default 18)

The existing status validation list on `Planting` is updated in code (no migration needed — it's a compile-time constant, not a DB constraint).

## Testing

- Unit tests for derived date calculations (nil-safe)
- Unit tests for `HourlyCheckWorker` — verify correct checks fire at correct hours, duplicate prevention, nil `weeks_to_start_indoors` skipped gracefully
- Unit tests for weather warning thresholds
- LiveView tests for Garden page section rendering with seedling statuses
- LiveView tests for Log Planting form adaptation when seedling seed selected
- LiveView tests for Seed edit form showing/hiding seedling fields
