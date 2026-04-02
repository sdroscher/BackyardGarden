# Frontend Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the Botanical & Lush design language across the app — replace the Phoenix boilerplate home page, restyle the nav, add full sort & filter to the seed library (responsive table + mobile cards), and redesign the seed detail page as a two-column layout.

**Architecture:** Pure frontend changes — template and CSS rewrites plus backend extension of `Seeds.list_seeds/1` to support two new filter fields (`planting_method`, `sun_requirement`) and dynamic sorting. No schema migrations required. All new data access paths are covered by unit tests before implementation.

**Tech Stack:** Elixir/Phoenix LiveView, Tailwind CSS v4, DaisyUI v5, HEEx templates

**Spec:** `docs/superpowers/specs/2026-04-01-frontend-redesign-design.md`

---

## File Map

| File | Change |
|---|---|
| `assets/css/app.css` | Update DaisyUI light theme to botanical greens |
| `lib/backyard_garden_web/components/layouts.ex` | Redesign nav; add `type_badge/1` component |
| `lib/backyard_garden_web/controllers/page_html/home.html.heex` | Replace Phoenix boilerplate with botanical landing page |
| `lib/backyard_garden/seeds/seeds.ex` | Add `list_planting_methods/0`, `list_sun_requirements/0`; extend `list_seeds/1` with `planting_method`/`sun_requirement` filters and sort |
| `lib/backyard_garden_web/live/seeds/index_live.ex` | Add `sort_field`/`sort_dir` assigns, `"sort"` event handler, mount new dropdown lists |
| `lib/backyard_garden_web/live/seeds/index_live.html.heex` | Restyle filter bar, sortable table headers, mobile card grid |
| `lib/backyard_garden_web/live/seeds/show_live.html.heex` | Two-column detail layout |
| `test/backyard_garden/seeds_test.exs` | Tests for new filters and sort |
| `test/backyard_garden_web/live/seeds/index_live_test.exs` | Tests for sort event and new filter dropdowns |

---

## Task 1: Update DaisyUI Light Theme

**Files:**
- Modify: `assets/css/app.css`

- [ ] **Step 1: Replace the light theme block**

In `assets/css/app.css`, replace the entire `@plugin "../vendor/daisyui-theme"` block for the `light` theme (lines 59–92) with:

```css
@plugin "../vendor/daisyui-theme" {
  name: "light";
  default: true;
  prefersdark: false;
  color-scheme: "light";
  --color-base-100: oklch(98% 0.014 150);
  --color-base-200: oklch(95% 0.02 150);
  --color-base-300: oklch(90% 0.03 150);
  --color-base-content: oklch(22% 0.07 155);
  --color-primary: oklch(40% 0.118 160);
  --color-primary-content: oklch(97% 0.014 160);
  --color-secondary: oklch(55% 0.027 264.364);
  --color-secondary-content: oklch(98% 0.002 247.839);
  --color-accent: oklch(0% 0 0);
  --color-accent-content: oklch(100% 0 0);
  --color-neutral: oklch(44% 0.017 285.786);
  --color-neutral-content: oklch(98% 0 0);
  --color-info: oklch(62% 0.214 259.815);
  --color-info-content: oklch(97% 0.014 254.604);
  --color-success: oklch(70% 0.14 182.503);
  --color-success-content: oklch(98% 0.014 180.72);
  --color-warning: oklch(66% 0.179 58.318);
  --color-warning-content: oklch(98% 0.022 95.277);
  --color-error: oklch(58% 0.253 17.585);
  --color-error-content: oklch(96% 0.015 12.422);
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;
  --size-selector: 0.21875rem;
  --size-field: 0.21875rem;
  --border: 1.5px;
  --depth: 1;
  --noise: 0;
}
```

Also update the `body` class in `lib/backyard_garden_web/components/layouts/root.html.heex` — replace:
```html
<body class="h-full bg-stone-50 text-stone-900 antialiased">
```
with:
```html
<body class="h-full bg-[#f0fdf4] text-[#14532d] antialiased">
```

- [ ] **Step 2: Verify the app compiles and starts**

```bash
mix phx.server
```

Open http://localhost:4000 — expect: page loads without errors (still shows Phoenix boilerplate, that's fine for now).

- [ ] **Step 3: Commit**

```bash
git add assets/css/app.css lib/backyard_garden_web/components/layouts/root.html.heex
git commit -m "style: apply botanical green DaisyUI light theme"
```

---

## Task 2: Redesign Navigation & Add Type Badge Component

**Files:**
- Modify: `lib/backyard_garden_web/components/layouts.ex`

The `type_badge/1` component goes in `layouts.ex` because it's used on both the index and show pages; placing it here makes it available wherever `Layouts` is imported. If a `core_components.ex` pattern is preferred in future, it can be moved.

- [ ] **Step 1: Replace `Layouts.app/1` and add `type_badge/1`**

Replace the entire `app/1` function and add the new `type_badge/1` component. The full updated section of `layouts.ex` (replacing lines 28–58):

```elixir
attr :flash, :map, required: true, doc: "the map of flash messages"

attr :current_scope, :map,
  default: nil,
  doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

slot :inner_block, required: true

def app(assigns) do
  ~H"""
  <header style="background: linear-gradient(90deg, #1a3a2a 0%, #2d6a4f 100%);" class="shadow-md">
    <nav
      aria-label="Main navigation"
      class="mx-auto max-w-5xl px-4 py-3 flex items-center justify-between"
    >
      <a href="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
        <span class="text-xl">🌿</span>
        <span class="text-[#d8f3dc] text-lg font-bold tracking-tight">BackyardGarden</span>
      </a>
      <div class="flex items-center gap-6 text-sm font-medium">
        <.nav_link href={~p"/seeds"} current_path={@current_scope}>Seeds</.nav_link>
        <a href="/garden" class="text-white/50 hover:text-[#95d5b2] transition-colors">
          My Garden
        </a>
        <a href="/calendar" class="text-white/50 hover:text-[#95d5b2] transition-colors">
          Calendar
        </a>
      </div>
    </nav>
  </header>

  <main class="mx-auto max-w-5xl px-4 py-8">
    <.flash_group flash={@flash} />
    {render_slot(@inner_block)}
  </main>
  """
end

defp nav_link(assigns) do
  ~H"""
  <a
    href={@href}
    class="text-[#95d5b2] border-b-2 border-[#52b788] pb-0.5 hover:text-white transition-colors"
  >
    {render_slot(@inner_block)}
  </a>
  """
end

@doc """
Renders a color-coded pill badge for a seed type.

## Examples

    <Layouts.type_badge type="Vegetable" />
    <Layouts.type_badge type={@seed.type} />

"""
attr :type, :string, required: true

def type_badge(assigns) do
  ~H"""
  <span class={[
    "text-xs font-medium px-2.5 py-0.5 rounded-full",
    type_badge_classes(@type)
  ]}>
    {@type}
  </span>
  """
end

defp type_badge_classes("Vegetable"), do: "text-[#16a34a] bg-[#dcfce7]"
defp type_badge_classes("Herb"), do: "text-[#7c3aed] bg-[#ede9fe]"
defp type_badge_classes("Flower"), do: "text-[#d97706] bg-[#fef3c7]"
defp type_badge_classes(_), do: "text-[#db2777] bg-[#fce7f3]"
```

Note: the `nav_link` component always applies the active style. In Phase 2, when LiveView sockets provide `@current_path`, this can be made conditional. For now it's acceptable since only `/seeds` is a real route.

- [ ] **Step 2: Run tests**

```bash
mix test
```

Expected: all tests pass. The nav is rendered in every page test — confirm no compilation errors.

- [ ] **Step 3: Commit**

```bash
git add lib/backyard_garden_web/components/layouts.ex
git commit -m "style: botanical nav gradient and type_badge component"
```

---

## Task 3: Replace Home Page

**Files:**
- Modify: `lib/backyard_garden_web/controllers/page_html/home.html.heex`

No new logic — this is a static template. The existing `page_controller_test.exs` tests a 200 response and will continue to pass.

- [ ] **Step 1: Replace the entire file contents**

```heex
<div class="space-y-8">
  <%!-- Hero --%>
  <div class="space-y-4">
    <p class="text-xs font-semibold text-[#52b788] uppercase tracking-widest">
      Your Garden, Planned
    </p>
    <h1 class="text-4xl font-extrabold text-[#14532d] leading-tight tracking-tight">
      Know what to plant,<br />and when to plant it.
    </h1>
    <p class="text-base text-[#4b7c5a] leading-relaxed max-w-lg">
      Browse your seed library, track plantings, and get timely reminders — all in one place.
    </p>
    <.link
      navigate={~p"/seeds"}
      class="inline-block bg-[#2d6a4f] text-white font-semibold px-5 py-2.5 rounded-lg hover:bg-[#1a3a2a] transition-colors"
    >
      Browse Seed Library →
    </.link>
  </div>

  <%!-- Dashboard placeholder grid --%>
  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-5 opacity-50">
      <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-2">
        🌱 Plant Now
      </p>
      <p class="text-sm text-stone-400 italic">Coming in Phase 3</p>
    </div>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-5 opacity-50">
      <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-2">
        ☁️ Weather
      </p>
      <p class="text-sm text-stone-400 italic">Coming in Phase 3</p>
    </div>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-5 opacity-50">
      <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-2">
        📅 Upcoming
      </p>
      <p class="text-sm text-stone-400 italic">Coming in Phase 3</p>
    </div>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-5 opacity-50">
      <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-2">
        ✓ Recently Planted
      </p>
      <p class="text-sm text-stone-400 italic">Coming in Phase 2</p>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Run tests**

```bash
mix test test/backyard_garden_web/controllers/page_controller_test.exs
```

Expected: passes (still returns 200, still renders within the app layout).

- [ ] **Step 3: Commit**

```bash
git add lib/backyard_garden_web/controllers/page_html/home.html.heex
git commit -m "feat: replace Phoenix boilerplate home page with botanical landing"
```

---

## Task 4: Extend Seeds Context — New Filters & Sort

**Files:**
- Modify: `lib/backyard_garden/seeds/seeds.ex`
- Modify: `test/backyard_garden/seeds_test.exs`

- [ ] **Step 1: Write failing tests for `list_planting_methods/0` and `list_sun_requirements/0`**

Add to `test/backyard_garden/seeds_test.exs` after the `list_cycles/0` describe block:

```elixir
describe "list_planting_methods/0" do
  test "returns distinct non-nil planting methods sorted" do
    seed_fixture(%{planting_method: "Direct Sow"})
    seed_fixture(%{planting_method: "Seedlings"})
    seed_fixture(%{planting_method: "Seedlings"})
    assert Seeds.list_planting_methods() == ["Direct Sow", "Seedlings"]
  end
end

describe "list_sun_requirements/0" do
  test "returns distinct non-nil sun requirements sorted" do
    seed_fixture(%{sun_requirement: "full_sun"})
    seed_fixture(%{sun_requirement: "partial_sun"})
    assert Seeds.list_sun_requirements() == ["full_sun", "partial_sun"]
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: 2 failures — `Seeds.list_planting_methods/0` and `Seeds.list_sun_requirements/0` are undefined.

- [ ] **Step 3: Implement `list_planting_methods/0` and `list_sun_requirements/0`**

Add to `lib/backyard_garden/seeds/seeds.ex` after `list_cycles/0`:

```elixir
@doc "Returns sorted distinct planting methods present in the database."
def list_planting_methods do
  Seed
  |> where([s], not is_nil(s.planting_method) and s.planting_method != "")
  |> select([s], s.planting_method)
  |> distinct(true)
  |> order_by([s], s.planting_method)
  |> Repo.all()
end

@doc "Returns sorted distinct sun requirements present in the database."
def list_sun_requirements do
  Seed
  |> where([s], not is_nil(s.sun_requirement) and s.sun_requirement != "")
  |> select([s], s.sun_requirement)
  |> distinct(true)
  |> order_by([s], s.sun_requirement)
  |> Repo.all()
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: all pass.

- [ ] **Step 5: Write failing tests for new `planting_method`/`sun_requirement` filters**

Add to the `list_seeds/1` describe block in `test/backyard_garden/seeds_test.exs`:

```elixir
test "filters by planting_method" do
  seed_fixture(%{name: "Basil", planting_method: "Seedlings"})
  seed_fixture(%{name: "Carrots", planting_method: "Direct Sow"})
  seeds = Seeds.list_seeds(%{planting_method: "Seedlings"})
  assert length(seeds) == 1
  assert hd(seeds).name == "Basil"
end

test "filters by sun_requirement" do
  seed_fixture(%{name: "Basil", sun_requirement: "full_sun"})
  seed_fixture(%{name: "Spinach", sun_requirement: "partial_sun"})
  seeds = Seeds.list_seeds(%{sun_requirement: "partial_sun"})
  assert length(seeds) == 1
  assert hd(seeds).name == "Spinach"
end
```

- [ ] **Step 6: Run tests to confirm they fail**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: 2 failures — `planting_method` and `sun_requirement` filters are not applied.

- [ ] **Step 7: Add `planting_method` and `sun_requirement` to `list_seeds/1`**

In `lib/backyard_garden/seeds/seeds.ex`, update `list_seeds/1`:

```elixir
def list_seeds(filters \\ %{}) do
  Seed
  |> filter_by(:type, filters[:type])
  |> filter_by(:brand, filters[:brand])
  |> filter_by(:cycle, filters[:cycle])
  |> filter_by(:planting_method, filters[:planting_method])
  |> filter_by(:sun_requirement, filters[:sun_requirement])
  |> filter_by_search(filters[:search])
  |> apply_sort(filters[:sort_field], filters[:sort_dir])
  |> Repo.all()
end
```

Replace the existing `|> order_by([s], s.name)` line — it's now handled by `apply_sort/3`. Add the private helper at the bottom of the private section:

```elixir
defp apply_sort(query, nil, _dir), do: order_by(query, [s], s.name)
defp apply_sort(query, "", _dir), do: order_by(query, [s], s.name)

defp apply_sort(query, field, dir) do
  sort_field = to_sort_atom(field)
  sort_dir = if dir == :desc, do: :desc, else: :asc
  order_by(query, [s], [{^sort_dir, field(s, ^sort_field)}])
end

defp to_sort_atom("type"), do: :type
defp to_sort_atom("brand"), do: :brand
defp to_sort_atom("cycle"), do: :cycle
defp to_sort_atom("ideal_planting_time"), do: :ideal_planting_time
defp to_sort_atom(_), do: :name
```

- [ ] **Step 8: Write failing tests for sort**

Add to the `list_seeds/1` describe block:

```elixir
test "sorts by name ascending by default" do
  seed_fixture(%{name: "Zucchini"})
  seed_fixture(%{name: "Basil"})
  seeds = Seeds.list_seeds(%{})
  assert hd(seeds).name == "Basil"
end

test "sorts by name descending" do
  seed_fixture(%{name: "Zucchini"})
  seed_fixture(%{name: "Basil"})
  seeds = Seeds.list_seeds(%{sort_field: "name", sort_dir: :desc})
  assert hd(seeds).name == "Zucchini"
end

test "sorts by type ascending" do
  seed_fixture(%{name: "Zucchini", type: "Vegetable"})
  seed_fixture(%{name: "Basil", type: "Herb"})
  seeds = Seeds.list_seeds(%{sort_field: "type", sort_dir: :asc})
  assert hd(seeds).type == "Herb"
end

test "unknown sort_field falls back to name sort" do
  seed_fixture(%{name: "Zucchini"})
  seed_fixture(%{name: "Basil"})
  seeds = Seeds.list_seeds(%{sort_field: "nonexistent", sort_dir: :asc})
  assert hd(seeds).name == "Basil"
end
```

- [ ] **Step 9: Run tests — expect failures on sort tests**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: the 4 new sort tests fail, others pass.

- [ ] **Step 10: Run all tests after implementation**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: all pass including the pre-existing "returns all seeds ordered by name when no filters" test (which exercises the `nil` sort path).

- [ ] **Step 11: Commit**

```bash
git add lib/backyard_garden/seeds/seeds.ex test/backyard_garden/seeds_test.exs
git commit -m "feat: extend list_seeds/1 with planting_method/sun_requirement filters and sort"
```

---

## Task 5: Extend IndexLive — Sort Event & New Filter Dropdowns

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/index_live.ex`
- Modify: `test/backyard_garden_web/live/seeds/index_live_test.exs`

- [ ] **Step 1: Write failing tests for sort**

Add to `test/backyard_garden_web/live/seeds/index_live_test.exs` (the existing `setup` block provides basil/carrots/echinacea — use those):

```elixir
test "sort event sorts by field ascending", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/seeds")

  html = render_click(view, "sort", %{"field" => "type"})

  # Herb < Vegetable alphabetically, so Basil and Echinacea (Herb) come before Carrots (Vegetable)
  basil_pos = :binary.match(html, "Basil") |> elem(0)
  carrots_pos = :binary.match(html, "Carrots") |> elem(0)
  assert basil_pos < carrots_pos
end

test "sort event toggles direction on second click", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/seeds")

  # First click: sort by name asc (default is already name asc, but explicit)
  render_click(view, "sort", %{"field" => "name"})
  # Second click on same field: name desc — Echinacea should come first
  html = render_click(view, "sort", %{"field" => "name"})

  echinacea_pos = :binary.match(html, "Echinacea") |> elem(0)
  basil_pos = :binary.match(html, "Basil") |> elem(0)
  assert echinacea_pos < basil_pos
end

test "sort event resets to asc when switching fields", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/seeds")

  # Sort by name desc first
  render_click(view, "sort", %{"field" => "name"})
  render_click(view, "sort", %{"field" => "name"})
  # Now switch to type — should be asc (Herb before Vegetable)
  html = render_click(view, "sort", %{"field" => "type"})

  basil_pos = :binary.match(html, "Basil") |> elem(0)
  carrots_pos = :binary.match(html, "Carrots") |> elem(0)
  assert basil_pos < carrots_pos
end
```

- [ ] **Step 2: Write failing tests for new filter dropdowns**

Add to `test/backyard_garden_web/live/seeds/index_live_test.exs`:

```elixir
test "renders planting_method dropdown", %{conn: conn} do
  {:ok, _view, html} = live(conn, ~p"/seeds")
  assert html =~ "planting_method"
end

test "renders sun_requirement dropdown", %{conn: conn} do
  {:ok, _view, html} = live(conn, ~p"/seeds")
  assert html =~ "sun_requirement"
end

test "filters by planting_method", %{conn: conn} do
  {:ok, direct_sow} =
    Seeds.create_seed(%{name: "Direct Sow Seed", planting_method: "Direct Sow", type: "Vegetable"})

  {:ok, seedlings} =
    Seeds.create_seed(%{name: "Seedlings Seed", planting_method: "Seedlings", type: "Herb"})

  {:ok, view, _html} = live(conn, ~p"/seeds")

  html =
    view
    |> form("#filter-form", %{
      "type" => "",
      "brand" => "",
      "cycle" => "",
      "planting_method" => "Direct Sow",
      "sun_requirement" => "",
      "search" => ""
    })
    |> render_change()

  assert html =~ direct_sow.name
  refute html =~ seedlings.name
end
```

- [ ] **Step 3: Run tests to confirm failures**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: the 6 new tests fail — `"sort"` event is unhandled, and the dropdown fields don't exist yet.

- [ ] **Step 4: Update `IndexLive`**

Replace the entire contents of `lib/backyard_garden_web/live/seeds/index_live.ex`:

```elixir
defmodule BackyardGardenWeb.Seeds.IndexLive do
  @moduledoc """
  LiveView for browsing, filtering, and sorting the seed library.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sort_field, "name")
     |> assign(:sort_dir, :asc)
     |> assign_filters(%{})
     |> assign(:types, Seeds.list_types())
     |> assign(:brands, Seeds.list_brands())
     |> assign(:cycles, Seeds.list_cycles())
     |> assign(:planting_methods, Seeds.list_planting_methods())
     |> assign(:sun_requirements, Seeds.list_sun_requirements())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      type: params["type"] || "",
      brand: params["brand"] || "",
      cycle: params["cycle"] || "",
      planting_method: params["planting_method"] || "",
      sun_requirement: params["sun_requirement"] || "",
      search: params["search"] || ""
    }

    {:noreply, assign_filters(socket, filters)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    new_dir =
      if field == socket.assigns.sort_field do
        if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
      else
        :asc
      end

    {:noreply,
     socket
     |> assign(:sort_field, field)
     |> assign(:sort_dir, new_dir)
     |> assign_filters(socket.assigns.filters)}
  end

  defp assign_filters(socket, filters) do
    seeds =
      Seeds.list_seeds(
        Map.merge(filters, %{
          sort_field: socket.assigns.sort_field,
          sort_dir: socket.assigns.sort_dir
        })
      )

    socket
    |> assign(:seeds, seeds)
    |> assign(:seed_count, length(seeds))
    |> assign(:filters, filters)
  end
end
```

- [ ] **Step 5: Run tests**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: all pass, including pre-existing filter tests (the filter form now has additional fields, but the existing tests submit a full params map and the new fields default to `""`).

- [ ] **Step 6: Run full test suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/index_live.ex \
        test/backyard_garden_web/live/seeds/index_live_test.exs
git commit -m "feat: add sort and planting_method/sun_requirement filters to IndexLive"
```

---

## Task 6: Restyle Seed Library Template

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/index_live.html.heex`

This task is purely visual — no new logic. The sort and filter behaviour was wired in Task 5.

- [ ] **Step 1: Replace the entire template**

```heex
<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-[#14532d]">Seed Library</h1>
    <span class="text-sm text-[#6b7280]">{@seed_count} seeds</span>
  </div>

  <%!-- Filter bar --%>
  <form id="filter-form" phx-change="filter" class="bg-white border border-[#bbf7d0] rounded-xl p-3 flex flex-wrap gap-2">
    <input
      type="text"
      name="search"
      value={@filters[:search]}
      placeholder="Search seeds..."
      phx-debounce="300"
      class="flex-1 min-w-[160px] rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none"
    />
    <select
      name="type"
      class="rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white"
    >
      <option value="">All types</option>
      <option :for={type <- @types} value={type} selected={@filters[:type] == type}>{type}</option>
    </select>
    <select
      name="brand"
      class="rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white"
    >
      <option value="">All brands</option>
      <option :for={brand <- @brands} value={brand} selected={@filters[:brand] == brand}>
        {brand}
      </option>
    </select>
    <select
      name="cycle"
      class="rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white"
    >
      <option value="">All cycles</option>
      <option :for={cycle <- @cycles} value={cycle} selected={@filters[:cycle] == cycle}>
        {cycle}
      </option>
    </select>
    <select
      name="planting_method"
      class="rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white"
    >
      <option value="">All methods</option>
      <option
        :for={method <- @planting_methods}
        value={method}
        selected={@filters[:planting_method] == method}
      >
        {method}
      </option>
    </select>
    <select
      name="sun_requirement"
      class="rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white"
    >
      <option value="">All sun</option>
      <option
        :for={sun <- @sun_requirements}
        value={sun}
        selected={@filters[:sun_requirement] == sun}
      >
        {sun |> String.replace("_", " ") |> String.capitalize()}
      </option>
    </select>
  </form>

  <%!-- Desktop table (hidden on mobile) --%>
  <div class="hidden sm:block overflow-x-auto rounded-xl border border-[#bbf7d0] shadow-sm">
    <table class="w-full text-sm">
      <thead class="bg-[#f0fdf4] text-[#14532d] text-left border-b-2 border-[#bbf7d0]">
        <tr>
          <th class="px-4 py-3 font-semibold">
            <button phx-click="sort" phx-value-field="name" class="flex items-center gap-1 hover:text-[#2d6a4f]">
              Name {sort_indicator(@sort_field, @sort_dir, "name")}
            </button>
          </th>
          <th class="px-4 py-3 font-semibold">
            <button phx-click="sort" phx-value-field="type" class="flex items-center gap-1 hover:text-[#2d6a4f]">
              Type {sort_indicator(@sort_field, @sort_dir, "type")}
            </button>
          </th>
          <th class="px-4 py-3 font-semibold hidden md:table-cell">
            <button phx-click="sort" phx-value-field="brand" class="flex items-center gap-1 hover:text-[#2d6a4f]">
              Brand {sort_indicator(@sort_field, @sort_dir, "brand")}
            </button>
          </th>
          <th class="px-4 py-3 font-semibold hidden md:table-cell">
            <button phx-click="sort" phx-value-field="cycle" class="flex items-center gap-1 hover:text-[#2d6a4f]">
              Cycle {sort_indicator(@sort_field, @sort_dir, "cycle")}
            </button>
          </th>
          <th class="px-4 py-3 font-semibold">
            <button
              phx-click="sort"
              phx-value-field="ideal_planting_time"
              class="flex items-center gap-1 hover:text-[#2d6a4f]"
            >
              Plant in {sort_indicator(@sort_field, @sort_dir, "ideal_planting_time")}
            </button>
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-[#f0fdf4]">
        <tr :for={seed <- @seeds} class="hover:bg-[#f0fdf4] transition-colors cursor-pointer odd:bg-white even:bg-[#fafafa]">
          <td class="px-4 py-3">
            <.link navigate={~p"/seeds/#{seed.id}"} class="font-semibold text-[#14532d] hover:text-[#2d6a4f] hover:underline">
              {seed.name}
            </.link>
          </td>
          <td class="px-4 py-3">
            <Layouts.type_badge type={seed.type} />
          </td>
          <td class="px-4 py-3 text-[#6b7280] hidden md:table-cell">{seed.brand}</td>
          <td class="px-4 py-3 text-[#6b7280] hidden md:table-cell">{seed.cycle}</td>
          <td class="px-4 py-3 text-[#374151]">{seed.ideal_planting_time}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <%!-- Mobile card grid (hidden on sm+) --%>
  <div class="grid grid-cols-2 gap-3 sm:hidden">
    <.link
      :for={seed <- @seeds}
      navigate={~p"/seeds/#{seed.id}"}
      class={[
        "bg-white border border-[#bbf7d0] rounded-xl p-3 space-y-1.5 hover:bg-[#f0fdf4] transition-colors",
        mobile_card_border(seed.type)
      ]}
    >
      <p class="font-bold text-[#14532d] text-sm leading-tight">{seed.name}</p>
      <Layouts.type_badge type={seed.type} />
      <p class="text-xs text-[#6b7280]">{seed.brand}</p>
      <p class="text-xs text-[#374151] font-medium">🌱 {seed.ideal_planting_time}</p>
    </.link>
  </div>
</div>
```

This template calls two helper functions (`sort_indicator/3` and `mobile_card_border/1`) that need to be defined in the LiveView module. Add them to `index_live.ex` as private functions:

```elixir
defp sort_indicator(sort_field, sort_dir, field) do
  if sort_field == field do
    if sort_dir == :asc, do: "↑", else: "↓"
  else
    assigns = %{}
    ~H[<span class="text-[#d1d5db]">↕</span>]
  end
end

defp mobile_card_border("Vegetable"), do: "border-t-[3px] border-t-[#16a34a]"
defp mobile_card_border("Herb"), do: "border-t-[3px] border-t-[#7c3aed]"
defp mobile_card_border("Flower"), do: "border-t-[3px] border-t-[#d97706]"
defp mobile_card_border(_), do: "border-t-[3px] border-t-[#db2777]"
```

- [ ] **Step 2: Run tests**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: all pass. The filter tests use `form("#filter-form", ...)` which works regardless of visual styling.

- [ ] **Step 3: Smoke test in browser**

```bash
mix phx.server
```

Open http://localhost:4000/seeds. Verify:
- Filter bar shows all 6 controls
- Table renders with sort arrows on headers
- Clicking a header sorts the list
- Shrink the browser to mobile width — table hides, card grid appears

- [ ] **Step 4: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/index_live.ex \
        lib/backyard_garden_web/live/seeds/index_live.html.heex
git commit -m "style: botanical seed library — sortable table, expanded filters, mobile cards"
```

---

## Task 7: Restyle Seed Detail Page

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/show_live.html.heex`

No logic changes — all rendering conditions (`supplier_product`, `care_html`, `notes`) are unchanged.

- [ ] **Step 1: Replace the entire template**

```heex
<div class="space-y-4">
  <div>
    <.link navigate={~p"/seeds"} class="text-sm text-[#2d6a4f] hover:underline">
      ← Seed Library
    </.link>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-[1fr_1.6fr] gap-4 items-start">
    <%!-- Left column: key facts --%>
    <div class="bg-white rounded-xl border border-[#bbf7d0] p-5 space-y-4">
      <div class="flex items-start justify-between gap-3">
        <h1 class="text-xl font-bold text-[#14532d] leading-tight">{@seed.name}</h1>
        <Layouts.type_badge type={@seed.type} />
      </div>

      <dl class="space-y-2 text-sm">
        <div class="flex justify-between py-2 border-b border-[#f0fdf4]">
          <dt class="text-[#6b7280]">Brand</dt>
          <dd class="text-[#14532d] font-medium">{@seed.brand || "—"}</dd>
        </div>
        <div class="flex justify-between py-2 border-b border-[#f0fdf4]">
          <dt class="text-[#6b7280]">Cycle</dt>
          <dd class="text-[#14532d] font-medium">{@seed.cycle || "—"}</dd>
        </div>
        <div class="flex justify-between py-2 border-b border-[#f0fdf4]">
          <dt class="text-[#6b7280]">Planting method</dt>
          <dd class="text-[#14532d] font-medium">{@seed.planting_method || "—"}</dd>
        </div>
        <div class="flex justify-between py-2 border-b border-[#f0fdf4]">
          <dt class="text-[#6b7280]">Ideal planting time</dt>
          <dd class="text-[#14532d] font-medium">{@seed.ideal_planting_time || "—"}</dd>
        </div>
        <div :if={@seed.maturity_days} class="flex justify-between py-2 border-b border-[#f0fdf4]">
          <dt class="text-[#6b7280]">Days to maturity</dt>
          <dd class="text-[#14532d] font-medium">{@seed.maturity_days} days</dd>
        </div>
        <div :if={@seed.sun_requirement} class="flex justify-between py-2">
          <dt class="text-[#6b7280]">Sun requirement</dt>
          <dd class="text-[#14532d] font-medium">
            {@seed.sun_requirement |> String.replace("_", " ") |> String.capitalize()}
          </dd>
        </div>
      </dl>

      <%= if @seed.supplier_product do %>
        <a
          href={@seed.supplier_product.url}
          target="_blank"
          rel="noopener noreferrer"
          class="block w-full text-center bg-[#2d6a4f] text-white font-semibold py-2.5 rounded-lg hover:bg-[#1a3a2a] transition-colors text-sm"
        >
          View on Supplier Site ↗
        </a>
      <% end %>
    </div>

    <%!-- Right column: growing content --%>
    <div class="space-y-4">
      <%= if @seed.notes && @seed.notes != "" do %>
        <div class="bg-white rounded-xl border border-[#bbf7d0] p-5">
          <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-2">Notes</p>
          <p class="text-sm text-[#374151] leading-relaxed">{@seed.notes}</p>
        </div>
      <% end %>

      <%= if @seed.supplier_product do %>
        <div class="bg-white rounded-xl border border-[#bbf7d0] p-5">
          <p class="text-xs font-semibold text-[#52b788] uppercase tracking-wide mb-3">
            From the Supplier
          </p>
          <div class="text-sm text-[#374151] space-y-2 leading-relaxed">
            {raw(@seed.supplier_product.description_html)}
          </div>
        </div>

        <%= if @seed.supplier_product.care_html do %>
          <div class="bg-white rounded-xl border border-[#bbf7d0] border-l-4 border-l-[#2d6a4f] p-5">
            <p class="text-xs font-semibold text-[#2d6a4f] uppercase tracking-wide mb-3">
              📖 Growing Guide
            </p>
            <div class="text-sm text-[#374151] space-y-3 leading-relaxed">
              {raw(@seed.supplier_product.care_html)}
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Run tests**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: all pass. The tests check for text content, not layout structure.

- [ ] **Step 3: Run full test suite and linter**

```bash
mix test && mix credo && mix sobelow
```

Expected: all pass with no warnings.

- [ ] **Step 4: Smoke test in browser**

```bash
mix phx.server
```

Open http://localhost:4000/seeds and click into a seed. Verify:
- Two-column layout on desktop (facts left, growing guide right)
- Single column on mobile (shrink browser)
- Supplier link button appears only for seeds with supplier data
- Growing guide has the green left border accent

- [ ] **Step 5: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/show_live.html.heex
git commit -m "style: two-column botanical seed detail page"
```

---

## Self-Review Checklist

After writing this plan, checking spec coverage:

| Spec requirement | Task |
|---|---|
| Update DaisyUI light theme to botanical greens | Task 1 |
| Update body background to `#f0fdf4` | Task 1 |
| Nav: dark green gradient, 🌿 logo, `#d8f3dc` text | Task 2 |
| `type_badge` component for reuse | Task 2 |
| Home page: hero + CTA + dashboard placeholders | Task 3 |
| New filters: planting_method, sun_requirement | Tasks 4 & 5 |
| Sort on all columns with toggle | Tasks 4 & 5 |
| Filter bar as white card with all 6 controls | Task 6 |
| Desktop table: sortable headers, badges, zebra rows | Task 6 |
| Mobile card grid with color-coded top border | Task 6 |
| Seed detail: two-column layout | Task 7 |
| Facts panel with label/value rows | Task 7 |
| Supplier button in facts panel | Task 7 |
| Notes, supplier, growing guide in right column | Task 7 |
| Back link | Task 7 |
