# Zone Editor Multi-Select Design

**Date:** 2026-04-15
**Status:** Approved

## Overview

Replace the free-text inputs for Sun Exposures, Allowed Types, and Allowed Cycles in the Garden Zone editor with toggle-pill multi-selectors. Update zone cards to display selected values as colour-coded mini pills instead of raw comma-separated text.

## Fixed Value Sets

These are the canonical values for each field:

| Field | Values |
|---|---|
| Sun Exposures | `full_sun`, `partial_sun`, `shade_tolerant` |
| Allowed Types | `Vegetable`, `Herb`, `Flower`, `Berry` |
| Allowed Cycles | `Annual`, `Biennial`, `Perennial` |

Sun exposure values are stored in snake_case and formatted for display at render time (`full_sun` → `Full Sun`).

## Storage

No schema or migration changes. All three fields remain `:string` columns storing comma-separated values (e.g. `"full_sun,partial_sun"`). This preserves SQLite test compatibility and avoids any data migration.

Joining and splitting happens in the LiveView — not in the schema or context.

## "Any" Behaviour

Each field has an explicit **Any** pill as its leftmost option:

- A new zone defaults to **Any** selected on all three fields, stored as an empty string `""`.
- Selecting a specific value automatically deselects **Any**.
- Selecting **Any** clears all specific selections.
- Saving with **Any** selected stores `""` (empty string), which the matching logic already treats as no constraint.

## Form UI — Toggle Pills

Each field renders as a horizontal pill group. Pills toggle green when selected; the **Any** pill renders grey when selected to distinguish it from specific values.

```
[Any]  [Full Sun ✓]  [Partial Sun ✓]  [Shade Tolerant]
```

The `phx-click` handler for each pill sends the field name and value. The LiveView maintains the current selections as a list in the socket assigns, converts to/from comma-separated string on load and save.

`phx-change` on the form is retained for name/description validation; the pill toggles bypass the form change event and use dedicated `toggle_pill` events instead.

## Zone Card UI — Mini Pills

The zone card replaces the plain text spans with colour-coded mini pill groups:

| Field | Pill colour |
|---|---|
| Sun Exposures | Amber (`bg-[#fef9c3] text-[#92400e]`) |
| Allowed Types | Green (`bg-[#dcfce7] text-[#14532d]`) |
| Allowed Cycles | Blue (`bg-[#e0f2fe] text-[#0c4a6e]`) |
| Any (all fields) | Grey (`bg-[#f3f4f6] text-[#6b7280]`) |

When a field is empty (any), a single grey **Any** pill is shown instead of nothing.

## LiveView Changes (`ZonesLive`)

- Add socket assigns `sun_selections`, `type_selections`, `cycle_selections` — each a `MapSet` of currently selected values.
- On `edit_zone` and `new_zone`, populate these assigns from the existing zone data (split the stored string) or default to empty `MapSet` (rendered as Any).
- Add `handle_event("toggle_pill", %{"field" => field, "value" => value}, socket)` that toggles the value in the appropriate `MapSet`, enforcing the Any logic.
- On `save_zone`, merge the three selections back into the params as comma-separated strings before passing to the context.
- On `cancel_form`, reset all three assigns.

## Template Changes (`zones_live.html.heex`)

- Replace the three `<.input type="text">` fields (and their hint `<p>` tags) with pill-group markup rendered from the socket assigns.
- Update the zone card section to render mini pills from parsed field values instead of raw string output.
- Extract a `format_sun/1` helper (or inline `String.replace/capitalize`) for converting snake_case sun values to display strings.

## Display Formatting

Sun exposure values are formatted at render time only — storage is unchanged:

```elixir
defp format_sun(value) do
  value |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
end
```

Types and Cycles are already properly capitalised in storage, so no formatting is needed.

## Out of Scope

- No changes to the `GardenZone` schema or Ecto changeset (other than potentially tightening validation).
- No changes to the `GardenZones` context functions.
- No database migration.
- No changes to the zone recommendation engine (`recommend_zones/2`) — it already does exact string matching against these stored values.
