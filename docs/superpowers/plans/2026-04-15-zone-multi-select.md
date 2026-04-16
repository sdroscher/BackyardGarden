# Zone Editor Multi-Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace free-text inputs for Sun Exposures, Allowed Types, and Allowed Cycles in the Zone editor with toggle-pill multi-selectors; update zone cards to display mini pills.

**Architecture:** All changes are confined to the LiveView layer — `ZonesLive` and its template. Storage stays as comma-separated strings (no migration). Pill selections are tracked as `MapSet`s in socket assigns; joined to strings on save, split on load.

**Tech Stack:** Elixir, Phoenix LiveView, HEEx, Tailwind CSS

**Spec:** `docs/superpowers/specs/2026-04-15-zone-multi-select-design.md`

---

## Files

| Action | File |
|---|---|
| Modify | `lib/backyard_garden_web/live/settings/zones_live.ex` |
| Modify | `lib/backyard_garden_web/live/settings/zones_live.html.heex` |
| Modify | `test/backyard_garden_web/live/settings/zones_live_test.exs` |

---

## Task 1: Backend — selection assigns, toggle_pill handler, save integration

Add `MapSet` assigns for the three fields. Handle `toggle_pill` events. Merge selections into `save_zone` params.

**Files:**
- Modify: `lib/backyard_garden_web/live/settings/zones_live.ex`
- Modify: `test/backyard_garden_web/live/settings/zones_live_test.exs`

- [ ] **Write failing tests**

Add to `test/backyard_garden_web/live/settings/zones_live_test.exs` (inside the existing module, after existing tests):

```elixir
test "toggle_pill selects a sun value", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/settings/zones")
  render_click(view, "new_zone", %{})
  render_click(view, "toggle_pill", %{"field" => "sun", "value" => "full_sun"})
  html = render(view)
  # pill should be in selected state (green background class)
  assert html =~ "full_sun"
end

test "toggle_pill deselects a value when clicked again", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/settings/zones")
  render_click(view, "new_zone", %{})
  render_click(view, "toggle_pill", %{"field" => "sun", "value" => "full_sun"})
  render_click(view, "toggle_pill", %{"field" => "sun", "value" => "full_sun"})
  html = render(view)
  # full_sun should NOT be in a selected pill (any pill selected)
  assert html =~ "pill-any selected" or html =~ ~s(pill any)
end

test "toggle_pill 'any' clears specific selections", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/settings/zones")
  render_click(view, "new_zone", %{})
  render_click(view, "toggle_pill", %{"field" => "type", "value" => "Vegetable"})
  render_click(view, "toggle_pill", %{"field" => "type", "value" => "any"})
  assert view.assigns.type_selections == MapSet.new()
end

test "creates a zone with pill-selected sun exposure", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/settings/zones")
  render_click(view, "new_zone", %{})
  render_click(view, "toggle_pill", %{"field" => "sun", "value" => "partial_sun"})

  html =
    view
    |> form("#zone-form", %{"zone" => %{"name" => "Shady Corner"}})
    |> render_submit()

  assert html =~ "Shady Corner"
  assert GardenZones.list_zones(view.assigns.current_user.id)
         |> Enum.any?(&(&1.sun_exposures == "partial_sun"))
end
```

Also update the existing `"creates a new zone via the form"` test — remove the `sun_exposures` from form params (no text input any more):

```elixir
test "creates a new zone via the form", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/settings/zones")
  render_click(view, "new_zone", %{})
  render_click(view, "toggle_pill", %{"field" => "sun", "value" => "full_sun"})

  html =
    view
    |> form("#zone-form", %{"zone" => %{"name" => "Fruit Patch"}})
    |> render_submit()

  assert html =~ "Fruit Patch"
end
```

- [ ] **Run tests to confirm they fail**

```bash
mix test test/backyard_garden_web/live/settings/zones_live_test.exs
```

Expected: failures on the new tests (function clause / key errors).

- [ ] **Implement in `zones_live.ex`**

Replace the full file with the updated version below:

```elixir
defmodule BackyardGardenWeb.Settings.ZonesLive do
  @moduledoc """
  LiveView for managing garden zones — add, edit, and delete zones.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone

  @sun_options [{"Full Sun", "full_sun"}, {"Partial Sun", "partial_sun"}, {"Shade Tolerant", "shade_tolerant"}]
  @type_options ["Vegetable", "Herb", "Flower", "Berry"]
  @cycle_options ["Annual", "Biennial", "Perennial"]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     socket
     |> assign(:page_title, "Garden Zones")
     |> assign(:zones, GardenZones.list_zones(user_id))
     |> assign(:editing_zone, nil)
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> assign(:sun_options, @sun_options)
     |> assign(:type_options, @type_options)
     |> assign(:cycle_options, @cycle_options)
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("new_zone", _params, socket) do
    changeset = GardenZone.changeset(%GardenZone{}, %{})

    {:noreply,
     socket
     |> assign(editing_zone: nil, show_form: true, form: to_form(changeset, as: "zone"))
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("edit_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    changeset = GardenZone.changeset(zone, %{})

    {:noreply,
     socket
     |> assign(editing_zone: zone, show_form: true, form: to_form(changeset, as: "zone"))
     |> assign(:sun_selections, parse_selections(zone.sun_exposures))
     |> assign(:type_selections, parse_selections(zone.allowed_types))
     |> assign(:cycle_selections, parse_selections(zone.allowed_cycles))}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(editing_zone: nil, show_form: false, form: nil)
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("toggle_pill", %{"field" => field, "value" => value}, socket) do
    key = selections_key(field)
    current = Map.get(socket.assigns, key)

    new_selections =
      cond do
        value == "any" -> MapSet.new()
        MapSet.member?(current, value) -> MapSet.delete(current, value)
        true -> MapSet.put(current, value)
      end

    {:noreply, assign(socket, key, new_selections)}
  end

  @impl true
  def handle_event("save_zone", %{"zone" => params}, socket) do
    user_id = socket.assigns.current_user.id

    params =
      params
      |> Map.put("sun_exposures", join_selections(socket.assigns.sun_selections))
      |> Map.put("allowed_types", join_selections(socket.assigns.type_selections))
      |> Map.put("allowed_cycles", join_selections(socket.assigns.cycle_selections))
      |> Map.put("user_id", user_id)

    result =
      case socket.assigns.editing_zone do
        nil -> GardenZones.create_zone(params)
        zone -> GardenZones.update_zone(zone, params)
      end

    case result do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> assign(:zones, GardenZones.list_zones(user_id))
         |> assign(:editing_zone, nil)
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> assign_empty_selections()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "zone"))}
    end
  end

  @impl true
  def handle_event("validate_zone", %{"zone" => params}, socket) do
    changeset =
      case socket.assigns.editing_zone do
        nil -> GardenZone.changeset(%GardenZone{}, params)
        zone -> GardenZone.changeset(zone, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "zone"))}
  end

  @impl true
  def handle_event("delete_zone", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    zone = GardenZones.get_zone!(id)

    case GardenZones.delete_zone(zone) do
      {:ok, _} ->
        {:noreply, assign(socket, :zones, GardenZones.list_zones(user_id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete zone.")}
    end
  end

  defp assign_empty_selections(socket) do
    socket
    |> assign(:sun_selections, MapSet.new())
    |> assign(:type_selections, MapSet.new())
    |> assign(:cycle_selections, MapSet.new())
  end

  defp parse_selections(nil), do: MapSet.new()
  defp parse_selections(""), do: MapSet.new()
  defp parse_selections(str), do: str |> String.split(",", trim: true) |> MapSet.new()

  defp join_selections(set), do: set |> MapSet.to_list() |> Enum.join(",")

  defp selections_key("sun"), do: :sun_selections
  defp selections_key("type"), do: :type_selections
  defp selections_key("cycle"), do: :cycle_selections

  defp format_sun(value) do
    value
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
```

- [ ] **Run tests**

```bash
mix test test/backyard_garden_web/live/settings/zones_live_test.exs
```

Expected: all pass.

- [ ] **Run formatter and linter**

```bash
mix format lib/backyard_garden_web/live/settings/zones_live.ex
mix credo lib/backyard_garden_web/live/settings/zones_live.ex
```

Fix any issues before committing.

- [ ] **Commit**

```bash
git add lib/backyard_garden_web/live/settings/zones_live.ex \
        test/backyard_garden_web/live/settings/zones_live_test.exs
git commit -m "feat: add toggle_pill handler and selection assigns to ZonesLive"
```

---

## Task 2: Update form template — pill groups replace text inputs

**Files:**
- Modify: `lib/backyard_garden_web/live/settings/zones_live.html.heex`

No new tests — covered by Task 1 integration tests and existing form tests.

- [ ] **Replace the three text input blocks in the form**

In the `<.form>` block, replace:

```heex
<div>
  <.input field={@form[:sun_exposures]} type="text" label="Sun Exposures" />
  <p class="mt-1 text-xs text-[#6b7280]">
    Comma-separated: full_sun, partial_sun, shade_tolerant
  </p>
</div>
<div>
  <.input field={@form[:allowed_types]} type="text" label="Allowed Types" />
  <p class="mt-1 text-xs text-[#6b7280]">Comma-separated, or blank for any</p>
</div>
<div>
  <.input field={@form[:allowed_cycles]} type="text" label="Allowed Cycles" />
  <p class="mt-1 text-xs text-[#6b7280]">Comma-separated, or blank for any</p>
</div>
```

With:

```heex
<div>
  <p class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">Sun Exposures</p>
  <div class="flex flex-wrap gap-2">
    <button
      type="button"
      phx-click="toggle_pill"
      phx-value-field="sun"
      phx-value-value="any"
      class={[
        "px-3 py-1.5 rounded-full text-sm border transition-colors",
        if(MapSet.size(@sun_selections) == 0,
          do: "bg-[#6b7280] text-white border-[#6b7280]",
          else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
        )
      ]}
    >
      Any
    </button>
    <%= for {label, value} <- @sun_options do %>
      <button
        type="button"
        phx-click="toggle_pill"
        phx-value-field="sun"
        phx-value-value={value}
        class={[
          "px-3 py-1.5 rounded-full text-sm border transition-colors",
          if(MapSet.member?(@sun_selections, value),
            do: "bg-[#2d6a4f] text-white border-[#2d6a4f]",
            else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
          )
        ]}
      >
        {label}
      </button>
    <% end %>
  </div>
</div>

<div>
  <p class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">
    Allowed Types <span class="font-normal text-[#6b7280]">(blank = any)</span>
  </p>
  <div class="flex flex-wrap gap-2">
    <button
      type="button"
      phx-click="toggle_pill"
      phx-value-field="type"
      phx-value-value="any"
      class={[
        "px-3 py-1.5 rounded-full text-sm border transition-colors",
        if(MapSet.size(@type_selections) == 0,
          do: "bg-[#6b7280] text-white border-[#6b7280]",
          else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
        )
      ]}
    >
      Any
    </button>
    <%= for option <- @type_options do %>
      <button
        type="button"
        phx-click="toggle_pill"
        phx-value-field="type"
        phx-value-value={option}
        class={[
          "px-3 py-1.5 rounded-full text-sm border transition-colors",
          if(MapSet.member?(@type_selections, option),
            do: "bg-[#2d6a4f] text-white border-[#2d6a4f]",
            else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
          )
        ]}
      >
        {option}
      </button>
    <% end %>
  </div>
</div>

<div>
  <p class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">
    Allowed Cycles <span class="font-normal text-[#6b7280]">(blank = any)</span>
  </p>
  <div class="flex flex-wrap gap-2">
    <button
      type="button"
      phx-click="toggle_pill"
      phx-value-field="cycle"
      phx-value-value="any"
      class={[
        "px-3 py-1.5 rounded-full text-sm border transition-colors",
        if(MapSet.size(@cycle_selections) == 0,
          do: "bg-[#6b7280] text-white border-[#6b7280]",
          else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
        )
      ]}
    >
      Any
    </button>
    <%= for option <- @cycle_options do %>
      <button
        type="button"
        phx-click="toggle_pill"
        phx-value-field="cycle"
        phx-value-value={option}
        class={[
          "px-3 py-1.5 rounded-full text-sm border transition-colors",
          if(MapSet.member?(@cycle_selections, option),
            do: "bg-[#2d6a4f] text-white border-[#2d6a4f]",
            else: "bg-white text-[#374151] border-[#bbf7d0] hover:bg-[#f0fdf4]"
          )
        ]}
      >
        {option}
      </button>
    <% end %>
  </div>
</div>
```

- [ ] **Run full test suite**

```bash
mix test test/backyard_garden_web/live/settings/zones_live_test.exs
```

Expected: all pass.

- [ ] **Format**

```bash
mix format lib/backyard_garden_web/live/settings/zones_live.html.heex
```

- [ ] **Commit**

```bash
git add lib/backyard_garden_web/live/settings/zones_live.html.heex
git commit -m "feat: replace zone form text inputs with toggle pill selectors"
```

---

## Task 3: Update zone cards — mini pills

**Files:**
- Modify: `lib/backyard_garden_web/live/settings/zones_live.html.heex`

- [ ] **Replace the zone card attribute display**

In the zone card section, replace:

```heex
<div class="flex flex-wrap gap-3 text-xs text-[#374151] mt-1">
  <span>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold">Sun:</span>
    {if zone.sun_exposures && zone.sun_exposures != "",
      do: zone.sun_exposures,
      else: "Any"}
  </span>
  <span>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold">
      Types:
    </span>
    {if zone.allowed_types && zone.allowed_types != "",
      do: zone.allowed_types,
      else: "Any"}
  </span>
  <span>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold">
      Cycles:
    </span>
    {if zone.allowed_cycles && zone.allowed_cycles != "",
      do: zone.allowed_cycles,
      else: "Any"}
  </span>
</div>
```

With:

```heex
<div class="space-y-2 mt-1">
  <div>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold text-xs">Sun</span>
    <div class="flex flex-wrap gap-1.5 mt-1">
      <%= if zone.sun_exposures && zone.sun_exposures != "" do %>
        <%= for val <- String.split(zone.sun_exposures, ",", trim: true) do %>
          <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#fef9c3] text-[#92400e]">
            {format_sun(val)}
          </span>
        <% end %>
      <% else %>
        <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#f3f4f6] text-[#6b7280]">
          Any
        </span>
      <% end %>
    </div>
  </div>
  <div>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold text-xs">Types</span>
    <div class="flex flex-wrap gap-1.5 mt-1">
      <%= if zone.allowed_types && zone.allowed_types != "" do %>
        <%= for val <- String.split(zone.allowed_types, ",", trim: true) do %>
          <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#dcfce7] text-[#14532d]">
            {val}
          </span>
        <% end %>
      <% else %>
        <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#f3f4f6] text-[#6b7280]">
          Any
        </span>
      <% end %>
    </div>
  </div>
  <div>
    <span class="text-[#52b788] uppercase tracking-wide font-semibold text-xs">Cycles</span>
    <div class="flex flex-wrap gap-1.5 mt-1">
      <%= if zone.allowed_cycles && zone.allowed_cycles != "" do %>
        <%= for val <- String.split(zone.allowed_cycles, ",", trim: true) do %>
          <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#e0f2fe] text-[#0c4a6e]">
            {val}
          </span>
        <% end %>
      <% else %>
        <span class="text-xs font-medium px-2.5 py-0.5 rounded-full bg-[#f3f4f6] text-[#6b7280]">
          Any
        </span>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Run full test suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Run precommit checks**

```bash
mix precommit
```

Fix any issues.

- [ ] **Commit**

```bash
git add lib/backyard_garden_web/live/settings/zones_live.html.heex
git commit -m "feat: display zone attributes as colour-coded mini pills"
```
