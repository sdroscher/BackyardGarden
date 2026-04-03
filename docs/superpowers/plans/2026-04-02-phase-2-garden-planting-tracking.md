# Phase 2 — Garden & Planting Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full garden management workflow: log plantings, track status (planned → planted → harvested), view a planting calendar, manage garden zones with zone recommendations, and edit seed sun/source data.

**Architecture:** Two new Ecto contexts (`Plantings`, `GardenZones`) back four new LiveViews (`Garden.IndexLive`, `Calendar.IndexLive`, `Settings.ZonesLive`, `Seeds.EditLive`). A `PlantingCalendar` module parses free-text ideal planting times into month ranges for the calendar view. No user_id in Phase 2 — auth is Phase 5; all data is global until then.

**Tech Stack:** Elixir + Phoenix LiveView + Ecto (SQLite3) + Tailwind CSS. No new dependencies.

**Note:** Task 2.6 from Plan.md (add `sun_requirement` to seeds) is already complete — the field exists in the migrations and schema from Phase 1.

---

## File Map

**New files:**
- `priv/repo/migrations/TIMESTAMP_create_garden_zones.exs`
- `priv/repo/migrations/TIMESTAMP_create_plantings.exs`
- `lib/backyard_garden/garden_zones/garden_zone.ex` — Ecto schema
- `lib/backyard_garden/garden_zones/garden_zones.ex` — context (CRUD + recommendation)
- `lib/backyard_garden/plantings/planting.ex` — Ecto schema
- `lib/backyard_garden/plantings/plantings.ex` — context (CRUD + calendar queries)
- `lib/backyard_garden/planting_calendar.ex` — ideal_planting_time text parser + calendar grid builder
- `lib/backyard_garden_web/live/seeds/edit_live.ex` — seed edit form LiveView
- `lib/backyard_garden_web/live/seeds/edit_live.html.heex`
- `lib/backyard_garden_web/live/garden/index_live.ex` — My Garden page
- `lib/backyard_garden_web/live/garden/index_live.html.heex`
- `lib/backyard_garden_web/live/calendar/index_live.ex` — Planting Calendar
- `lib/backyard_garden_web/live/calendar/index_live.html.heex`
- `lib/backyard_garden_web/live/settings/zones_live.ex` — Zone settings
- `lib/backyard_garden_web/live/settings/zones_live.html.heex`
- `lib/mix/tasks/plantings.import.ex` — CSV import task
- `priv/repo/garden_zones.exs` — default zone seed data
- `test/backyard_garden/garden_zones_test.exs`
- `test/backyard_garden/plantings_test.exs`
- `test/backyard_garden/planting_calendar_test.exs`
- `test/backyard_garden_web/live/seeds/edit_live_test.exs`
- `test/backyard_garden_web/live/garden/index_live_test.exs`
- `test/backyard_garden_web/live/calendar/index_live_test.exs`
- `test/backyard_garden_web/live/settings/zones_live_test.exs`

**Modified files:**
- `lib/backyard_garden_web/router.ex` — add `/garden`, `/calendar`, `/settings/zones`, `/seeds/:id/edit` routes
- `lib/backyard_garden_web/components/layouts.ex` — activate Garden + Calendar nav links
- `lib/backyard_garden/seeds/seeds.ex` — add `update_seed/2`
- `test/backyard_garden/seeds_test.exs` — add `update_seed/2` tests

---

## Task 1: Add Content-Security-Policy header (Phase 1 carry-over)

**Files:**
- Modify: `lib/backyard_garden_web/router.ex`

Sobelow flagged `Config.CSP` because `put_secure_browser_headers` was called without a CSP map. Fix by passing one. LiveView requires WebSocket connections (`ws:`/`wss:`) and `'unsafe-inline'` for its injected scripts and styles (nonce-based CSP is a future hardening step).

- [ ] **Step 1: Update the browser pipeline in router.ex**

Replace:
```elixir
plug :put_secure_browser_headers
```
with:
```elixir
plug :put_secure_browser_headers, %{
  "content-security-policy" =>
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws: wss:"
}
```

- [ ] **Step 2: Verify the security scan no longer flags it**

```bash
mix sobelow
```

Expected: `Config.CSP` warning is gone. Exit status 0.

- [ ] **Step 3: Run the full test suite to ensure nothing broke**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/backyard_garden_web/router.ex
git commit -m "fix: add Content-Security-Policy header to browser pipeline"
```

---

## Task 2: Garden zones data layer

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_garden_zones.exs`
- Create: `lib/backyard_garden/garden_zones/garden_zone.ex`
- Create: `lib/backyard_garden/garden_zones/garden_zones.ex`
- Create: `test/backyard_garden/garden_zones_test.exs`

Garden zones have comma-separated string fields for `sun_exposures`, `allowed_types`, and `allowed_cycles` (matching the SQLite storage plan). The context exposes parsing helpers used by the recommendation engine.

- [ ] **Step 1: Generate the migration**

```bash
mix ecto.gen.migration create_garden_zones
```

This prints the new filename, e.g. `priv/repo/migrations/20260402XXXXXX_create_garden_zones.exs`. Open that file and replace its contents with:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreateGardenZones do
  use Ecto.Migration

  def change do
    create table(:garden_zones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :sun_exposures, :string
      add :allowed_types, :string
      add :allowed_cycles, :string

      timestamps()
    end

    create index(:garden_zones, [:name])
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
mix ecto.migrate
```

Expected: `create table garden_zones`, `create index garden_zones_name_index`.

- [ ] **Step 3: Write the failing tests**

Create `test/backyard_garden/garden_zones_test.exs`:

```elixir
defmodule BackyardGarden.GardenZonesTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone

  defp zone_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Test Zone",
      sun_exposures: "full_sun",
      allowed_types: "Vegetable",
      allowed_cycles: "Annual"
    }

    {:ok, zone} = GardenZones.create_zone(Map.merge(defaults, attrs))
    zone
  end

  describe "list_zones/0" do
    test "returns all zones ordered by name" do
      zone_fixture(%{name: "Back Garden"})
      zone_fixture(%{name: "Herb Boxes"})
      zones = GardenZones.list_zones()
      assert Enum.map(zones, & &1.name) == ["Back Garden", "Herb Boxes"]
    end
  end

  describe "get_zone!/1" do
    test "returns zone by id" do
      zone = zone_fixture()
      assert GardenZones.get_zone!(zone.id).name == zone.name
    end

    test "raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        GardenZones.get_zone!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_zone/1" do
    test "creates a zone with valid attrs" do
      attrs = %{name: "Sunny Beds", sun_exposures: "full_sun"}
      assert {:ok, %GardenZone{name: "Sunny Beds"}} = GardenZones.create_zone(attrs)
    end

    test "returns error changeset when name is missing" do
      assert {:error, changeset} = GardenZones.create_zone(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_zone/2" do
    test "updates zone fields" do
      zone = zone_fixture()
      assert {:ok, updated} = GardenZones.update_zone(zone, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error changeset for blank name" do
      zone = zone_fixture()
      assert {:error, _changeset} = GardenZones.update_zone(zone, %{name: ""})
    end
  end

  describe "delete_zone/1" do
    test "deletes the zone" do
      zone = zone_fixture()
      assert {:ok, _} = GardenZones.delete_zone(zone)
      assert_raise Ecto.NoResultsError, fn -> GardenZones.get_zone!(zone.id) end
    end
  end

  describe "parse_csv_field/1" do
    test "parses comma-separated string into list" do
      assert GardenZones.parse_csv_field("full_sun,partial_sun") == ["full_sun", "partial_sun"]
    end

    test "returns empty list for nil" do
      assert GardenZones.parse_csv_field(nil) == []
    end

    test "returns empty list for empty string" do
      assert GardenZones.parse_csv_field("") == []
    end

    test "trims whitespace from values" do
      assert GardenZones.parse_csv_field("full_sun, partial_sun") == ["full_sun", "partial_sun"]
    end
  end
end
```

- [ ] **Step 4: Run the tests to see them fail**

```bash
mix test test/backyard_garden/garden_zones_test.exs
```

Expected: compilation error — `BackyardGarden.GardenZones` not defined.

- [ ] **Step 5: Create the schema**

Create `lib/backyard_garden/garden_zones/garden_zone.ex`:

```elixir
defmodule BackyardGarden.GardenZones.GardenZone do
  @moduledoc """
  Schema for a named garden zone with sun exposure and planting constraints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "garden_zones" do
    field :name, :string
    field :description, :string
    field :sun_exposures, :string
    field :allowed_types, :string
    field :allowed_cycles, :string

    timestamps()
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :description, :sun_exposures, :allowed_types, :allowed_cycles])
    |> validate_required([:name])
  end
end
```

- [ ] **Step 6: Create the context**

Create `lib/backyard_garden/garden_zones/garden_zones.ex`:

```elixir
defmodule BackyardGarden.GardenZones do
  @moduledoc """
  Context for managing garden zones and zone recommendations.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.GardenZones.GardenZone

  @doc "Returns all zones ordered by name."
  def list_zones do
    GardenZone
    |> order_by([z], z.name)
    |> Repo.all()
  end

  @doc "Returns a single zone by id. Raises if not found."
  def get_zone!(id), do: Repo.get!(GardenZone, id)

  @doc "Creates a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def create_zone(attrs) do
    %GardenZone{}
    |> GardenZone.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def update_zone(%GardenZone{} = zone, attrs) do
    zone
    |> GardenZone.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def delete_zone(%GardenZone{} = zone), do: Repo.delete(zone)

  @doc """
  Parses a comma-separated string field into a list of trimmed strings.
  Returns [] for nil or empty string.
  """
  def parse_csv_field(nil), do: []
  def parse_csv_field(""), do: []

  def parse_csv_field(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
```

- [ ] **Step 7: Run tests and verify they pass**

```bash
mix test test/backyard_garden/garden_zones_test.exs
```

Expected: all tests pass.

- [ ] **Step 8: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add priv/repo/migrations lib/backyard_garden/garden_zones test/backyard_garden/garden_zones_test.exs
git commit -m "feat: add GardenZones context with CRUD and CSV field parser"
```

---

## Task 3: Plantings data layer

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_plantings.exs`
- Create: `lib/backyard_garden/plantings/planting.ex`
- Create: `lib/backyard_garden/plantings/plantings.ex`
- Create: `test/backyard_garden/plantings_test.exs`

- [ ] **Step 1: Generate the migration**

```bash
mix ecto.gen.migration create_plantings
```

Open the generated file and replace its contents with:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreatePlantings do
  use Ecto.Migration

  def change do
    create table(:plantings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :seed_id, references(:seeds, type: :binary_id, on_delete: :restrict), null: false
      add :zone_id, references(:garden_zones, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, default: "planned"
      add :planted_at, :date
      add :harvested_at, :date
      add :location, :string
      add :notes, :text

      timestamps()
    end

    create index(:plantings, [:seed_id])
    create index(:plantings, [:status])
    create index(:plantings, [:planted_at])
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
mix ecto.migrate
```

Expected: `create table plantings` and three index creation lines.

- [ ] **Step 3: Write the failing tests**

Create `test/backyard_garden/plantings_test.exs`:

```elixir
defmodule BackyardGarden.PlantingsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Plantings
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Seeds

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs \\ %{}) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  describe "list_plantings/0" do
    test "returns all plantings" do
      seed = seed_fixture()
      planting_fixture(seed)
      assert length(Plantings.list_plantings()) == 1
    end
  end

  describe "list_plantings_by_status/1" do
    test "returns only plantings with the given status" do
      seed = seed_fixture()
      planting_fixture(seed, %{status: "planned"})
      planting_fixture(seed, %{status: "planted"})
      planned = Plantings.list_plantings_by_status("planned")
      assert length(planned) == 1
      assert hd(planned).status == "planned"
    end
  end

  describe "get_planting!/1" do
    test "returns planting by id" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert Plantings.get_planting!(planting.id).id == planting.id
    end

    test "raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Plantings.get_planting!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_planting/1" do
    test "creates planting with valid attrs" do
      seed = seed_fixture()
      attrs = %{seed_id: seed.id, status: "planned", planted_at: ~D[2026-03-27]}
      assert {:ok, %Planting{status: "planned"}} = Plantings.create_planting(attrs)
    end

    test "returns error changeset when seed_id is missing" do
      assert {:error, changeset} = Plantings.create_planting(%{status: "planned"})
      assert %{seed_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status is one of planned/planted/harvested" do
      seed = seed_fixture()
      assert {:error, changeset} = Plantings.create_planting(%{seed_id: seed.id, status: "invalid"})
      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "update_planting/2" do
    test "updates planting status" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert {:ok, updated} = Plantings.update_planting(planting, %{status: "planted", planted_at: ~D[2026-03-27]})
      assert updated.status == "planted"
      assert updated.planted_at == ~D[2026-03-27]
    end

    test "returns error changeset for invalid status" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert {:error, _changeset} = Plantings.update_planting(planting, %{status: "bad"})
    end
  end

  describe "delete_planting/1" do
    test "deletes the planting" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert {:ok, _} = Plantings.delete_planting(planting)
      assert_raise Ecto.NoResultsError, fn -> Plantings.get_planting!(planting.id) end
    end
  end

  describe "list_plantings_for_month/1" do
    test "returns plantings planted in the given month" do
      seed = seed_fixture()
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-04-15]})
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-10]})
      april = ~D[2026-04-01]
      results = Plantings.list_plantings_for_month(april)
      assert length(results) == 1
      assert hd(results).planted_at == ~D[2026-04-15]
    end

    test "returns plantings with harvest due in the given month" do
      seed = seed_fixture(%{maturity_days: 50})
      # planted March 15 + 50 days = May 4 → harvest due in May
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-15]})
      may = ~D[2026-05-01]
      results = Plantings.list_plantings_for_month(may)
      assert length(results) == 1
    end
  end
end
```

- [ ] **Step 4: Run the tests to see them fail**

```bash
mix test test/backyard_garden/plantings_test.exs
```

Expected: compilation error — `BackyardGarden.Plantings` not defined.

- [ ] **Step 5: Create the schema**

Create `lib/backyard_garden/plantings/planting.ex`:

```elixir
defmodule BackyardGarden.Plantings.Planting do
  @moduledoc """
  Schema for a seed planting event — tracks status, dates, location, and notes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(planned planted harvested)

  schema "plantings" do
    field :status, :string, default: "planned"
    field :planted_at, :date
    field :harvested_at, :date
    field :location, :string
    field :notes, :string

    belongs_to :seed, BackyardGarden.Seeds.Seed
    belongs_to :zone, BackyardGarden.GardenZones.GardenZone

    timestamps()
  end

  def changeset(planting, attrs) do
    planting
    |> cast(attrs, [:seed_id, :zone_id, :status, :planted_at, :harvested_at, :location, :notes])
    |> validate_required([:seed_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:seed_id)
    |> foreign_key_constraint(:zone_id)
  end
end
```

- [ ] **Step 6: Create the context**

Create `lib/backyard_garden/plantings/plantings.ex`:

```elixir
defmodule BackyardGarden.Plantings do
  @moduledoc """
  Context for managing garden plantings.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Plantings.Planting

  @doc "Returns all plantings preloaded with seed and zone, ordered by inserted_at desc."
  def list_plantings do
    Planting
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc "Returns all plantings with the given status, preloaded with seed and zone."
  def list_plantings_by_status(status) do
    Planting
    |> where([p], p.status == ^status)
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc """
  Returns plantings relevant to the given month — either planted in that month,
  or with a harvest due date (planted_at + seed.maturity_days) in that month.
  """
  def list_plantings_for_month(%Date{} = first_day) do
    last_day = Date.end_of_month(first_day)

    Planting
    |> where([p], not is_nil(p.planted_at))
    |> preload(:seed)
    |> Repo.all()
    |> Enum.filter(fn planting ->
      planted_in_month?(planting, first_day, last_day) or
        harvest_due_in_month?(planting, first_day, last_day)
    end)
  end

  @doc "Returns a single planting by id with seed and zone preloaded. Raises if not found."
  def get_planting!(id) do
    Planting
    |> preload([:seed, :zone])
    |> Repo.get!(id)
  end

  @doc "Creates a planting. Returns {:ok, planting} or {:error, changeset}."
  def create_planting(attrs) do
    %Planting{}
    |> Planting.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a planting. Returns {:ok, planting} or {:error, changeset}."
  def update_planting(%Planting{} = planting, attrs) do
    planting
    |> Planting.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a planting. Returns {:ok, planting} or {:error, changeset}."
  def delete_planting(%Planting{} = planting), do: Repo.delete(planting)

  # Private helpers

  defp planted_in_month?(%Planting{planted_at: date}, first_day, last_day) do
    not is_nil(date) and Date.compare(date, first_day) != :lt and
      Date.compare(date, last_day) != :gt
  end

  defp harvest_due_in_month?(%Planting{planted_at: planted_at, seed: seed}, first_day, last_day) do
    with %Date{} <- planted_at,
         maturity when is_integer(maturity) and maturity > 0 <- seed.maturity_days do
      harvest_date = Date.add(planted_at, maturity)
      Date.compare(harvest_date, first_day) != :lt and
        Date.compare(harvest_date, last_day) != :gt
    else
      _ -> false
    end
  end
end
```

- [ ] **Step 7: Run the tests and verify they pass**

```bash
mix test test/backyard_garden/plantings_test.exs
```

Expected: all tests pass.

- [ ] **Step 8: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add priv/repo/migrations lib/backyard_garden/plantings test/backyard_garden/plantings_test.exs
git commit -m "feat: add Plantings context with CRUD and calendar queries"
```

---

## Task 4: Default garden zones seed data

**Files:**
- Create: `priv/repo/garden_zones.exs`

This script is run once to populate the three default zones described in the plan. It is idempotent — skips any zone whose name already exists.

- [ ] **Step 1: Create the seed script**

Create `priv/repo/garden_zones.exs`:

```elixir
# priv/repo/garden_zones.exs
# Run with: mix run priv/repo/garden_zones.exs
#
# Idempotent: skips zones that already exist (matched by name).

alias BackyardGarden.Repo
alias BackyardGarden.GardenZones.GardenZone
import Ecto.Query

zones = [
  %{
    name: "Sunny Raised Planters",
    description: "South-facing raised beds — full sun all day",
    sun_exposures: "full_sun",
    allowed_types: "Vegetable",
    allowed_cycles: "Annual"
  },
  %{
    name: "Herb Boxes",
    description: "Raised boxes along the fence — variable sun depending on position",
    sun_exposures: "full_sun,partial_sun,shade_tolerant",
    allowed_types: "Herb",
    allowed_cycles: ""
  },
  %{
    name: "Back Garden",
    description: "Open garden bed — full sun to part shade, ideal for perennials",
    sun_exposures: "full_sun,partial_sun,shade_tolerant",
    allowed_types: "",
    allowed_cycles: "Perennial,Biennial"
  }
]

existing_names =
  GardenZone
  |> select([z], z.name)
  |> Repo.all()
  |> MapSet.new()

Enum.each(zones, fn attrs ->
  if MapSet.member?(existing_names, attrs.name) do
    IO.puts("Skipping (already exists): #{attrs.name}")
  else
    Repo.insert!(%GardenZone{
      id: Ecto.UUID.generate(),
      name: attrs.name,
      description: attrs.description,
      sun_exposures: attrs.sun_exposures,
      allowed_types: attrs.allowed_types,
      allowed_cycles: attrs.allowed_cycles
    })

    IO.puts("Created: #{attrs.name}")
  end
end)
```

- [ ] **Step 2: Run the script**

```bash
mix run priv/repo/garden_zones.exs
```

Expected output:
```
Created: Sunny Raised Planters
Created: Herb Boxes
Created: Back Garden
```

- [ ] **Step 3: Verify idempotency**

```bash
mix run priv/repo/garden_zones.exs
```

Expected output:
```
Skipping (already exists): Sunny Raised Planters
Skipping (already exists): Herb Boxes
Skipping (already exists): Back Garden
```

- [ ] **Step 4: Commit**

```bash
git add priv/repo/garden_zones.exs
git commit -m "feat: add default garden zones seed script"
```

---

## Task 5: update_seed/2 + Seed edit LiveView

**Files:**
- Modify: `lib/backyard_garden/seeds/seeds.ex`
- Modify: `test/backyard_garden/seeds_test.exs`
- Create: `lib/backyard_garden_web/live/seeds/edit_live.ex`
- Create: `lib/backyard_garden_web/live/seeds/edit_live.html.heex`
- Create: `test/backyard_garden_web/live/seeds/edit_live_test.exs`
- Modify: `lib/backyard_garden_web/router.ex`

This adds `update_seed/2` to the Seeds context and a `/seeds/:id/edit` LiveView that allows editing `sun_requirement` and `source_url` (and all other seed fields).

- [ ] **Step 1: Write the failing test for update_seed/2**

In `test/backyard_garden/seeds_test.exs`, add a new describe block after `describe "create_seed/1"`:

```elixir
describe "update_seed/2" do
  test "updates a seed with valid attrs" do
    seed = seed_fixture(%{sun_requirement: nil})
    assert {:ok, updated} = Seeds.update_seed(seed, %{sun_requirement: "full_sun"})
    assert updated.sun_requirement == "full_sun"
  end

  test "updates source_url" do
    seed = seed_fixture()
    assert {:ok, updated} = Seeds.update_seed(seed, %{source_url: "https://example.com"})
    assert updated.source_url == "https://example.com"
  end

  test "returns error changeset when name is set to blank" do
    seed = seed_fixture()
    assert {:error, changeset} = Seeds.update_seed(seed, %{name: ""})
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 2: Run the test to see it fail**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: compilation error — `Seeds.update_seed/2` not defined.

- [ ] **Step 3: Add update_seed/2 to the context**

In `lib/backyard_garden/seeds/seeds.ex`, add after `create_seed/1`:

```elixir
@doc "Updates a seed. Returns {:ok, seed} or {:error, changeset}."
def update_seed(%Seed{} = seed, attrs) do
  seed
  |> Seed.changeset(attrs)
  |> Repo.update()
end
```

- [ ] **Step 4: Run the context tests to verify they pass**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: all tests pass.

- [ ] **Step 5: Write the failing LiveView tests**

Create `test/backyard_garden_web/live/seeds/edit_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Seeds.EditLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds

  setup do
    {:ok, seed} =
      Seeds.create_seed(%{
        name: "Basil",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Annual",
        maturity_days: 60
      })

    %{seed: seed}
  end

  test "renders edit form with seed fields pre-filled", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}/edit")
    assert html =~ "Basil"
    assert html =~ "Metchosin Farm"
    assert html =~ "Edit Seed"
  end

  test "updates seed and redirects to show page", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}/edit")

    {:ok, _show_view, html} =
      view
      |> form("#seed-edit-form", %{
        "seed" => %{"sun_requirement" => "full_sun", "source_url" => "https://example.com"}
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/seeds/#{seed.id}")

    assert html =~ "full_sun"
  end

  test "shows validation error when name is cleared", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}/edit")

    html =
      view
      |> form("#seed-edit-form", %{"seed" => %{"name" => ""}})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end

  test "back link navigates to show page", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}/edit")
    assert html =~ ~p"/seeds/#{seed.id}"
  end
end
```

- [ ] **Step 6: Run the tests to see them fail**

```bash
mix test test/backyard_garden_web/live/seeds/edit_live_test.exs
```

Expected: failure — no route for `/seeds/:id/edit`.

- [ ] **Step 7: Add the route**

In `lib/backyard_garden_web/router.ex`, add after the existing seed routes:

```elixir
live "/seeds/:id/edit", Seeds.EditLive, :edit
```

- [ ] **Step 8: Create the EditLive module**

Create `lib/backyard_garden_web/live/seeds/edit_live.ex`:

```elixir
defmodule BackyardGardenWeb.Seeds.EditLive do
  @moduledoc """
  LiveView for editing an existing seed's fields.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds
  alias BackyardGarden.Seeds.Seed

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed!(id)
    changeset = Seed.changeset(seed, %{})
    {:ok, assign(socket, seed: seed, form: to_form(changeset))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Edit #{socket.assigns.seed.name}")}
  end

  @impl true
  def handle_event("validate", %{"seed" => params}, socket) do
    changeset =
      socket.assigns.seed
      |> Seed.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"seed" => params}, socket) do
    case Seeds.update_seed(socket.assigns.seed, params) do
      {:ok, seed} ->
        {:noreply, push_navigate(socket, to: ~p"/seeds/#{seed.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

- [ ] **Step 9: Create the template**

Create `lib/backyard_garden_web/live/seeds/edit_live.html.heex`:

```heex
<div class="space-y-4">
  <div class="flex items-center gap-3">
    <a href={~p"/seeds/#{@seed.id}"} class="text-[#52b788] hover:text-[#2d6a4f] text-sm">
      ← Back to {@seed.name}
    </a>
  </div>

  <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
    <h1 class="text-2xl font-bold text-[#14532d] mb-6">Edit Seed</h1>

    <.form id="seed-edit-form" for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Name</label>
          <.input field={@form[:name]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Brand</label>
          <.input field={@form[:brand]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Type</label>
          <.input field={@form[:type]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Cycle</label>
          <.input field={@form[:cycle]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Sun Requirement</label>
          <.input field={@form[:sun_requirement]} type="select" options={[
            {"— not set —", ""},
            {"Full Sun", "full_sun"},
            {"Partial Sun", "partial_sun"},
            {"Shade Tolerant", "shade_tolerant"}
          ]} class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Planting Method</label>
          <.input field={@form[:planting_method]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Ideal Planting Time</label>
          <.input field={@form[:ideal_planting_time]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Maturity (days)</label>
          <.input field={@form[:maturity_days]} type="number" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-[#374151] mb-1">Source URL</label>
          <.input field={@form[:source_url]} type="text" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-[#374151] mb-1">Notes</label>
          <.input field={@form[:notes]} type="textarea" rows="3" class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
      </div>

      <div class="flex gap-3 pt-2">
        <button type="submit" class="bg-[#2d6a4f] text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-[#1a3a2a] transition-colors">
          Save changes
        </button>
        <a href={~p"/seeds/#{@seed.id}"} class="rounded-lg px-4 py-2 text-sm font-medium border border-[#bbf7d0] text-[#374151] hover:bg-[#f0fdf4] transition-colors">
          Cancel
        </a>
      </div>
    </.form>
  </div>
</div>
```

- [ ] **Step 10: Run the LiveView tests**

```bash
mix test test/backyard_garden_web/live/seeds/edit_live_test.exs
```

Expected: all tests pass.

- [ ] **Step 11: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 12: Commit**

```bash
git add lib/backyard_garden/seeds/seeds.ex \
        lib/backyard_garden_web/live/seeds/edit_live.ex \
        lib/backyard_garden_web/live/seeds/edit_live.html.heex \
        lib/backyard_garden_web/router.ex \
        test/backyard_garden/seeds_test.exs \
        test/backyard_garden_web/live/seeds/edit_live_test.exs
git commit -m "feat: add update_seed/2 and seed edit form at /seeds/:id/edit"
```

---

## Task 6: My Garden page — list by status

**Files:**
- Create: `lib/backyard_garden_web/live/garden/index_live.ex`
- Create: `lib/backyard_garden_web/live/garden/index_live.html.heex`
- Create: `test/backyard_garden_web/live/garden/index_live_test.exs`
- Modify: `lib/backyard_garden_web/router.ex`
- Modify: `lib/backyard_garden_web/components/layouts.ex`

The page groups plantings into three sections: PLANTED, PLANNED, HARVESTED. Each planting shows seed name, planted_at, estimated harvest, zone name, and status action buttons.

- [ ] **Step 1: Write the failing tests**

Create `test/backyard_garden_web/live/garden/index_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Garden.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds
  alias BackyardGarden.Plantings

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", type: "Vegetable", cycle: "Annual", maturity_days: 50}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs \\ %{}) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  test "renders My Garden heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "My Garden"
  end

  test "shows PLANTED section with planting", %{conn: conn} do
    seed = seed_fixture(%{name: "Spinach"})
    planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Spinach"
    assert html =~ "planted"
  end

  test "shows PLANNED section with planting", %{conn: conn} do
    seed = seed_fixture(%{name: "Carrots"})
    planting_fixture(seed, %{status: "planned"})

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Carrots"
  end

  test "shows HARVESTED section", %{conn: conn} do
    seed = seed_fixture(%{name: "Lettuce"})
    planting_fixture(seed, %{status: "harvested", planted_at: ~D[2026-03-01], harvested_at: ~D[2026-04-01]})

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Lettuce"
  end

  test "shows Log Planting button", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Log Planting"
  end

  test "mark planted action updates status", %{conn: conn} do
    seed = seed_fixture(%{name: "Basil"})
    planting = planting_fixture(seed, %{status: "planned"})

    {:ok, view, _html} = live(conn, ~p"/garden")
    html = render_click(view, "mark_planted", %{"id" => planting.id})
    assert html =~ "planted"
  end

  test "mark harvested action updates status", %{conn: conn} do
    seed = seed_fixture(%{name: "Basil"})
    planting = planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, view, _html} = live(conn, ~p"/garden")
    html = render_click(view, "mark_harvested", %{"id" => planting.id})
    assert html =~ "harvested"
  end
end
```

- [ ] **Step 2: Run to see it fail**

```bash
mix test test/backyard_garden_web/live/garden/index_live_test.exs
```

Expected: failure — no route `/garden`.

- [ ] **Step 3: Add the route**

In `lib/backyard_garden_web/router.ex`, add:

```elixir
live "/garden", Garden.IndexLive, :index
```

- [ ] **Step 4: Create the LiveView module**

Create `lib/backyard_garden_web/live/garden/index_live.ex`:

```elixir
defmodule BackyardGardenWeb.Garden.IndexLive do
  @moduledoc """
  LiveView for the My Garden page — lists plantings grouped by status.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Plantings
  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Garden")
     |> assign(:seeds, Seeds.list_seeds())
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> load_plantings()}
  end

  @impl true
  def handle_event("mark_planted", %{"id" => id}, socket) do
    planting = Plantings.get_planting!(id)
    today = Date.utc_today()

    attrs = %{
      status: "planted",
      planted_at: planting.planted_at || today
    }

    {:ok, _} = Plantings.update_planting(planting, attrs)
    {:noreply, load_plantings(socket)}
  end

  @impl true
  def handle_event("mark_harvested", %{"id" => id}, socket) do
    planting = Plantings.get_planting!(id)
    {:ok, _} = Plantings.update_planting(planting, %{status: "harvested", harvested_at: Date.utc_today()})
    {:noreply, load_plantings(socket)}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    changeset = Plantings.change_planting(%Plantings.Planting{})
    {:noreply, assign(socket, show_form: true, form: to_form(changeset))}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form: nil)}
  end

  @impl true
  def handle_event("save_planting", %{"planting" => params}, socket) do
    case Plantings.create_planting(params) do
      {:ok, _planting} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> load_plantings()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp load_plantings(socket) do
    socket
    |> assign(:planted, Plantings.list_plantings_by_status("planted"))
    |> assign(:planned, Plantings.list_plantings_by_status("planned"))
    |> assign(:harvested, Plantings.list_plantings_by_status("harvested"))
  end

  defp estimated_harvest(%{planted_at: nil}), do: nil
  defp estimated_harvest(%{seed: %{maturity_days: nil}}), do: nil
  defp estimated_harvest(%{seed: %{maturity_days: 0}}), do: nil

  defp estimated_harvest(%{planted_at: planted_at, seed: %{maturity_days: days}}) do
    Date.add(planted_at, days)
  end
end
```

Note: `Plantings.change_planting/1` is needed by the form — add it to the context in the next step.

- [ ] **Step 5: Add change_planting/1 helper to the Plantings context**

In `lib/backyard_garden/plantings/plantings.ex`, add:

```elixir
@doc "Returns a changeset for a planting (used to initialise forms)."
def change_planting(%Planting{} = planting, attrs \\ %{}) do
  Planting.changeset(planting, attrs)
end
```

- [ ] **Step 6: Create the template**

Create `lib/backyard_garden_web/live/garden/index_live.html.heex`:

```heex
<div class="space-y-6">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-[#14532d]">My Garden</h1>
    <button
      phx-click="show_form"
      class="bg-[#2d6a4f] text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-[#1a3a2a] transition-colors"
    >
      + Log Planting
    </button>
  </div>

  <%!-- Log Planting form (inline modal) --%>
  <%= if @show_form do %>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-6 space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-[#14532d]">Log a Planting</h2>
        <button phx-click="hide_form" class="text-[#6b7280] hover:text-[#374151] text-xl leading-none">&times;</button>
      </div>
      <.form id="log-planting-form" for={@form} phx-submit="save_planting" class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-[#374151] mb-1">Seed</label>
          <.input field={@form[:seed_id]} type="select"
            options={Enum.map(@seeds, &{&1.name, &1.id})}
            prompt="Select a seed…"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Status</label>
          <.input field={@form[:status]} type="select"
            options={[{"Planned", "planned"}, {"Planted", "planted"}, {"Harvested", "harvested"}]}
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Date planted</label>
          <.input field={@form[:planted_at]} type="date"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-[#374151] mb-1">Location (optional)</label>
          <.input field={@form[:location]} type="text" placeholder="e.g. east end of bed"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-[#374151] mb-1">Notes (optional)</label>
          <.input field={@form[:notes]} type="textarea" rows="2"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="md:col-span-2 flex gap-3">
          <button type="submit" class="bg-[#2d6a4f] text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-[#1a3a2a] transition-colors">
            Save
          </button>
          <button type="button" phx-click="hide_form" class="rounded-lg px-4 py-2 text-sm font-medium border border-[#bbf7d0] text-[#374151] hover:bg-[#f0fdf4] transition-colors">
            Cancel
          </button>
        </div>
      </.form>
    </div>
  <% end %>

  <%!-- PLANTED section --%>
  <section class="bg-white border border-[#bbf7d0] rounded-xl overflow-hidden">
    <div class="px-4 py-3 border-b border-[#bbf7d0] flex items-center gap-2">
      <span class="w-2.5 h-2.5 rounded-full bg-[#2d6a4f] inline-block"></span>
      <span class="text-sm font-semibold text-[#52b788] uppercase tracking-wide">Planted ({length(@planted)})</span>
    </div>
    <%= if Enum.empty?(@planted) do %>
      <p class="px-4 py-4 text-sm text-[#6b7280]">No planted items yet.</p>
    <% else %>
      <ul class="divide-y divide-[#f0fdf4]">
        <%= for planting <- @planted do %>
          <li class="px-4 py-3 flex items-start justify-between gap-4">
            <div class="space-y-0.5">
              <p class="font-medium text-[#14532d]">{planting.seed.name}</p>
              <p class="text-xs text-[#6b7280]">
                Planted {planting.planted_at}
                <%= if harvest = estimated_harvest(planting) do %>
                  &middot; Ready ~{harvest}
                <% end %>
                <%= if planting.location && planting.location != "" do %>
                  &middot; {planting.location}
                <% end %>
              </p>
            </div>
            <button
              phx-click="mark_harvested"
              phx-value-id={planting.id}
              class="text-xs rounded-lg border border-[#bbf7d0] px-3 py-1 text-[#374151] hover:bg-[#f0fdf4] transition-colors whitespace-nowrap"
            >
              Mark Harvested
            </button>
          </li>
        <% end %>
      </ul>
    <% end %>
  </section>

  <%!-- PLANNED section --%>
  <section class="bg-white border border-[#bbf7d0] rounded-xl overflow-hidden">
    <div class="px-4 py-3 border-b border-[#bbf7d0] flex items-center gap-2">
      <span class="w-2.5 h-2.5 rounded-full bg-[#6b7280] border-2 border-[#6b7280] inline-block"></span>
      <span class="text-sm font-semibold text-[#52b788] uppercase tracking-wide">Planned ({length(@planned)})</span>
    </div>
    <%= if Enum.empty?(@planned) do %>
      <p class="px-4 py-4 text-sm text-[#6b7280]">No planned items yet.</p>
    <% else %>
      <ul class="divide-y divide-[#f0fdf4]">
        <%= for planting <- @planned do %>
          <li class="px-4 py-3 flex items-start justify-between gap-4">
            <div class="space-y-0.5">
              <p class="font-medium text-[#14532d]">{planting.seed.name}</p>
              <p class="text-xs text-[#6b7280]">
                Ideal: {planting.seed.ideal_planting_time || "—"}
                <%= if planting.location && planting.location != "" do %>
                  &middot; {planting.location}
                <% end %>
              </p>
            </div>
            <button
              phx-click="mark_planted"
              phx-value-id={planting.id}
              class="text-xs rounded-lg border border-[#bbf7d0] px-3 py-1 text-[#374151] hover:bg-[#f0fdf4] transition-colors whitespace-nowrap"
            >
              Mark Planted
            </button>
          </li>
        <% end %>
      </ul>
    <% end %>
  </section>

  <%!-- HARVESTED section --%>
  <section class="bg-white border border-[#bbf7d0] rounded-xl overflow-hidden">
    <div class="px-4 py-3 border-b border-[#bbf7d0] flex items-center gap-2">
      <span class="w-2.5 h-2.5 rounded-full bg-[#52b788] inline-block"></span>
      <span class="text-sm font-semibold text-[#52b788] uppercase tracking-wide">Harvested ({length(@harvested)})</span>
    </div>
    <%= if Enum.empty?(@harvested) do %>
      <p class="px-4 py-4 text-sm text-[#6b7280]">Nothing harvested yet.</p>
    <% else %>
      <ul class="divide-y divide-[#f0fdf4]">
        <%= for planting <- @harvested do %>
          <li class="px-4 py-3">
            <p class="font-medium text-[#14532d]">{planting.seed.name}</p>
            <p class="text-xs text-[#6b7280]">
              Planted {planting.planted_at} &middot; Harvested {planting.harvested_at}
            </p>
          </li>
        <% end %>
      </ul>
    <% end %>
  </section>
</div>
```

- [ ] **Step 7: Activate the Garden nav link**

In `lib/backyard_garden_web/components/layouts.ex`, replace the placeholder anchor for My Garden:

```elixir
<a href="/garden" class="text-white/50 hover:text-[#95d5b2] transition-colors">
  My Garden
</a>
```

with:

```elixir
<.nav_link href={~p"/garden"} current_scope={@current_scope}>My Garden</.nav_link>
```

- [ ] **Step 8: Run the tests**

```bash
mix test test/backyard_garden_web/live/garden/index_live_test.exs
```

Expected: all tests pass.

- [ ] **Step 9: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/backyard_garden_web/live/garden \
        lib/backyard_garden_web/router.ex \
        lib/backyard_garden_web/components/layouts.ex \
        lib/backyard_garden/plantings/plantings.ex \
        test/backyard_garden_web/live/garden
git commit -m "feat: add My Garden page with planting list and status actions"
```

---

## Task 7: Import plantings from CSV

**Files:**
- Create: `lib/mix/tasks/plantings.import.ex`

This task reads `Seed Planting 2026.csv`, matches each row to a seed by name+brand, and creates a planting record. Rows with a non-empty `Actually Planted` column become `planted` status; others become `planned`. Idempotent: skips seeds that already have any planting.

- [ ] **Step 1: Verify the CSV column positions**

```bash
head -1 "Seed Planting 2026.csv"
```

Expected: `Plant,Brand,Type,Cycle,When Bought,Planting Method,Ideal Planting time,Actually Planted,Maturity ,Location,Notes`

Columns (0-indexed): 0=Plant, 1=Brand, 7=Actually Planted, 9=Location, 10=Notes.

- [ ] **Step 2: Create the mix task**

Create `lib/mix/tasks/plantings.import.ex`:

```elixir
defmodule Mix.Tasks.Plantings.Import do
  @moduledoc """
  Imports planting history from `Seed Planting 2026.csv`.

  Run with: mix plantings.import

  Idempotent — skips seeds that already have a planting record.
  Rows with a non-empty `Actually Planted` date become status=planted;
  others become status=planned.
  """

  use Mix.Task

  alias BackyardGarden.Repo
  alias BackyardGarden.Seeds
  alias BackyardGarden.Plantings

  NimbleCSV.define(PlantingsCSVParser, separator: ",", escape: "\"")

  @shortdoc "Import planting history from CSV"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    csv_path = Path.join(File.cwd!(), "Seed Planting 2026.csv")

    unless File.exists?(csv_path) do
      Mix.shell().error("ERROR: #{csv_path} not found. Run from project root.")
      System.halt(1)
    end

    existing_seed_ids =
      Plantings.list_plantings()
      |> Enum.map(& &1.seed_id)
      |> MapSet.new()

    results =
      csv_path
      |> File.stream!()
      |> PlantingsCSVParser.parse_stream(skip_headers: true)
      |> Enum.reduce(%{imported: 0, skipped: 0, unmatched: 0}, fn row, acc ->
        padded = row ++ List.duplicate("", 12)

        [name, brand | _] = padded
        actually_planted = Enum.at(padded, 7) |> String.trim()
        location = Enum.at(padded, 9) |> String.trim()
        notes = Enum.at(padded, 10) |> String.trim()

        case find_seed(name, brand) do
          nil ->
            Mix.shell().info("  No match for: #{name} (#{brand})")
            %{acc | unmatched: acc.unmatched + 1}

          seed ->
            if MapSet.member?(existing_seed_ids, seed.id) do
              Mix.shell().info("  Skipping (already exists): #{seed.name}")
              %{acc | skipped: acc.skipped + 1}
            else
              {status, planted_at} = parse_planted_date(actually_planted)

              attrs = %{
                seed_id: seed.id,
                status: status,
                planted_at: planted_at,
                location: if(location == "", do: nil, else: location),
                notes: if(notes == "", do: nil, else: notes)
              }

              {:ok, _} = Plantings.create_planting(attrs)
              Mix.shell().info("  Imported: #{seed.name} (#{status})")
              %{acc | imported: acc.imported + 1}
            end
        end
      end)

    Mix.shell().info("\nDone. Imported: #{results.imported}, Skipped: #{results.skipped}, Unmatched: #{results.unmatched}")
  end

  defp find_seed(name, brand) do
    name = String.trim(name)
    brand = String.trim(brand)

    Seeds.list_seeds()
    |> Enum.find(fn seed ->
      String.downcase(seed.name) == String.downcase(name) and
        String.downcase(seed.brand || "") == String.downcase(brand)
    end)
  end

  defp parse_planted_date(""), do: {"planned", nil}

  defp parse_planted_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> {"planted", date}
      _ ->
        Mix.shell().error("  Could not parse date '#{date_str}', treating as planned")
        {"planned", nil}
    end
  end
end
```

- [ ] **Step 3: Run the import task**

```bash
mix plantings.import
```

Expected: each seed in the CSV is either imported or noted as skipped/unmatched. Seeds with `Actually Planted` dates get `status=planted`. Final summary line printed.

- [ ] **Step 4: Verify idempotency**

```bash
mix plantings.import
```

Expected: all lines show "Skipping (already exists)". `Imported: 0`.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/plantings.import.ex
git commit -m "feat: add mix plantings.import task for CSV planting history"
```

---

## Task 8: PlantingCalendar module — ideal planting time parser

**Files:**
- Create: `lib/backyard_garden/planting_calendar.ex`
- Create: `test/backyard_garden/planting_calendar_test.exs`

This module converts `ideal_planting_time` free-text values (e.g. "Early Spring", "April-July") into `{start_month, end_month}` integer tuples. It also builds the calendar grid for a given month.

- [ ] **Step 1: Write the failing tests**

Create `test/backyard_garden/planting_calendar_test.exs`:

```elixir
defmodule BackyardGarden.PlantingCalendarTest do
  use ExUnit.Case, async: true

  alias BackyardGarden.PlantingCalendar

  describe "parse_ideal_months/1" do
    test "returns nil for nil input" do
      assert PlantingCalendar.parse_ideal_months(nil) == nil
    end

    test "returns nil for empty string" do
      assert PlantingCalendar.parse_ideal_months("") == nil
    end

    test "parses 'Early Spring' to March-April" do
      assert PlantingCalendar.parse_ideal_months("Early Spring") == {3, 4}
    end

    test "parses 'Late Spring' to April-May" do
      assert PlantingCalendar.parse_ideal_months("Late Spring") == {4, 5}
    end

    test "parses 'Spring' to March-May" do
      assert PlantingCalendar.parse_ideal_months("Spring") == {3, 5}
    end

    test "parses 'Early/Late Spring' to March-May" do
      assert PlantingCalendar.parse_ideal_months("Early/Late Spring") == {3, 5}
    end

    test "parses month range 'April-July'" do
      assert PlantingCalendar.parse_ideal_months("April-July") == {4, 7}
    end

    test "parses 'Late April' to April-April" do
      assert PlantingCalendar.parse_ideal_months("Late April") == {4, 4}
    end

    test "parses 'Early April' to April-April" do
      assert PlantingCalendar.parse_ideal_months("Early April") == {4, 4}
    end

    test "parses 'Summer' to June-August" do
      assert PlantingCalendar.parse_ideal_months("Summer") == {6, 8}
    end

    test "parses 'Fall' to September-October" do
      assert PlantingCalendar.parse_ideal_months("Fall") == {9, 10}
    end

    test "returns nil for unrecognised string" do
      assert PlantingCalendar.parse_ideal_months("whenever") == nil
    end
  end

  describe "weeks_for_month/1" do
    test "returns list of week lists for April 2026" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      # April 2026 starts on Wednesday (day 3)
      assert length(weeks) == 5
      # First week: Monday=nil, Tuesday=nil, Wednesday=Apr 1 …
      [first_week | _] = weeks
      assert Enum.at(first_week, 0) == nil
      assert Enum.at(first_week, 1) == nil
      assert Enum.at(first_week, 2) == ~D[2026-04-01]
    end

    test "each week has exactly 7 entries" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      assert Enum.all?(weeks, fn week -> length(week) == 7 end)
    end

    test "all actual dates are in the given month" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      dates = weeks |> List.flatten() |> Enum.reject(&is_nil/1)
      assert Enum.all?(dates, fn d -> d.month == 4 and d.year == 2026 end)
    end
  end

  describe "month_range/1" do
    test "returns first and last day for April 2026" do
      {first, last} = PlantingCalendar.month_range(~D[2026-04-01])
      assert first == ~D[2026-04-01]
      assert last == ~D[2026-04-30]
    end
  end
end
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
mix test test/backyard_garden/planting_calendar_test.exs
```

Expected: compilation error — `BackyardGarden.PlantingCalendar` not defined.

- [ ] **Step 3: Create the module**

Create `lib/backyard_garden/planting_calendar.ex`:

```elixir
defmodule BackyardGarden.PlantingCalendar do
  @moduledoc """
  Helpers for the planting calendar: ideal planting time parser and month grid builder.
  """

  @month_names %{
    "january" => 1, "february" => 2, "march" => 3, "april" => 4,
    "may" => 5, "june" => 6, "july" => 7, "august" => 8,
    "september" => 9, "october" => 10, "november" => 11, "december" => 12
  }

  @doc """
  Parses an `ideal_planting_time` string into a `{start_month, end_month}` tuple (1-12).
  Returns nil for unrecognised or empty input.

  ## Examples

      iex> parse_ideal_months("Early Spring")
      {3, 4}
      iex> parse_ideal_months("April-July")
      {4, 7}
  """
  def parse_ideal_months(nil), do: nil
  def parse_ideal_months(""), do: nil

  def parse_ideal_months(text) do
    text = String.trim(text)
    do_parse(String.downcase(text))
  end

  @doc """
  Returns a list of week lists (each week is 7 entries of `Date.t() | nil`)
  for the month containing `first_day`. Weeks start on Monday.
  nil entries pad the first and last weeks.
  """
  def weeks_for_month(%Date{} = first_day) do
    first = %{first_day | day: 1}
    last = Date.end_of_month(first)

    all_dates = Date.range(first, last) |> Enum.to_list()

    # Day of week: 1=Monday … 7=Sunday
    leading_nils = List.duplicate(nil, Date.day_of_week(first) - 1)
    trailing_nils = List.duplicate(nil, 7 - Date.day_of_week(last))

    (leading_nils ++ all_dates ++ trailing_nils)
    |> Enum.chunk_every(7)
  end

  @doc "Returns {first_day, last_day} for the month containing the given date."
  def month_range(%Date{} = date) do
    first = %{date | day: 1}
    {first, Date.end_of_month(first)}
  end

  # Private parsers — ordered from most specific to least specific

  defp do_parse("early spring"), do: {3, 4}
  defp do_parse("early/late spring"), do: {3, 5}
  defp do_parse("late spring"), do: {4, 5}
  defp do_parse("spring"), do: {3, 5}
  defp do_parse("early summer"), do: {6, 7}
  defp do_parse("summer"), do: {6, 8}
  defp do_parse("early fall"), do: {9, 9}
  defp do_parse("fall"), do: {9, 10}
  defp do_parse("autumn"), do: {9, 10}
  defp do_parse("early winter"), do: {11, 12}
  defp do_parse("winter"), do: {11, 2}

  # "April-July" → {4, 7}
  defp do_parse(text) do
    with [start_name, end_name] <- String.split(text, "-", parts: 2),
         start_m when not is_nil(start_m) <- Map.get(@month_names, String.trim(start_name)),
         end_m when not is_nil(end_m) <- Map.get(@month_names, String.trim(end_name)) do
      {start_m, end_m}
    else
      _ -> parse_qualified_month(text)
    end
  end

  # "late april" → {4, 4}, "early april" → {4, 4}
  defp parse_qualified_month(text) do
    cond do
      String.starts_with?(text, "early ") ->
        month_from_suffix(text, "early ")

      String.starts_with?(text, "late ") ->
        month_from_suffix(text, "late ")

      true ->
        Map.get(@month_names, text) |> then(fn
          nil -> nil
          m -> {m, m}
        end)
    end
  end

  defp month_from_suffix(text, prefix) do
    suffix = String.replace_prefix(text, prefix, "")

    case Map.get(@month_names, suffix) do
      nil -> nil
      m -> {m, m}
    end
  end
end
```

- [ ] **Step 4: Run the tests**

```bash
mix test test/backyard_garden/planting_calendar_test.exs
```

Expected: all tests pass.

- [ ] **Step 5: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden/planting_calendar.ex test/backyard_garden/planting_calendar_test.exs
git commit -m "feat: add PlantingCalendar module with ideal planting time parser and grid builder"
```

---

## Task 9: Planting Calendar LiveView

**Files:**
- Create: `lib/backyard_garden_web/live/calendar/index_live.ex`
- Create: `lib/backyard_garden_web/live/calendar/index_live.html.heex`
- Create: `test/backyard_garden_web/live/calendar/index_live_test.exs`
- Modify: `lib/backyard_garden_web/router.ex`
- Modify: `lib/backyard_garden_web/components/layouts.ex`

The calendar renders a month grid. Each cell shows up to three event types: blue dot = planted that day, yellow dot = harvest due that day, green label = seed ideal window opens this month (displayed on the 1st of that month).

- [ ] **Step 1: Write the failing tests**

Create `test/backyard_garden_web/live/calendar/index_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Calendar.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds
  alias BackyardGarden.Plantings

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Basil", type: "Herb", cycle: "Annual", maturity_days: 60}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  test "renders calendar heading with current month", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ "Calendar"
  end

  test "renders navigation arrows", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ "prev_month"
    assert html =~ "next_month"
  end

  test "navigating to previous month changes heading", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/calendar")
    current_month_label = extract_month_label(html)
    new_html = render_click(view, "prev_month", %{})
    refute extract_month_label(new_html) == current_month_label
  end

  test "navigating to next month changes heading", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/calendar")
    current_month_label = extract_month_label(html)
    new_html = render_click(view, "next_month", %{})
    refute extract_month_label(new_html) == current_month_label
  end

  test "shows planted seed on its planted_at date", %{conn: conn} do
    seed = seed_fixture(%{name: "Spinach"})
    {:ok, planting} = Plantings.create_planting(%{
      seed_id: seed.id,
      status: "planted",
      planted_at: ~D[2026-04-15]
    })

    # Navigate to April 2026
    {:ok, view, _html} = live(conn, ~p"/calendar")
    # Click to reach April 2026 — adjust based on today's month
    html = navigate_to_april(view)
    assert html =~ "Spinach"
    _ = planting
  end

  defp extract_month_label(html) do
    case Regex.run(~r/<h2[^>]*>([^<]+)<\/h2>/, html) do
      [_, label] -> label
      _ -> html
    end
  end

  defp navigate_to_april(view) do
    today = Date.utc_today()
    diff = (2026 - today.year) * 12 + (4 - today.month)

    Enum.reduce(1..max(diff, 1), render(view), fn _, _acc ->
      render_click(view, "next_month", %{})
    end)
  end
end
```

- [ ] **Step 2: Run to see it fail**

```bash
mix test test/backyard_garden_web/live/calendar/index_live_test.exs
```

Expected: failure — no route for `/calendar`.

- [ ] **Step 3: Add the route**

In `lib/backyard_garden_web/router.ex`:

```elixir
live "/calendar", Calendar.IndexLive, :index
```

- [ ] **Step 4: Create the LiveView module**

Create `lib/backyard_garden_web/live/calendar/index_live.ex`:

```elixir
defmodule BackyardGardenWeb.Calendar.IndexLive do
  @moduledoc """
  LiveView for the planting calendar — month grid with planted, harvest-due,
  and ideal-window markers.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.PlantingCalendar
  alias BackyardGarden.Plantings
  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    current_month = %{today | day: 1}
    {:ok, assign(socket, :current_month, current_month) |> load_calendar_data()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Planting Calendar")}
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    new_month = socket.assigns.current_month |> Date.add(-1) |> then(&%{&1 | day: 1})
    {:noreply, assign(socket, :current_month, new_month) |> load_calendar_data()}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    last_day = Date.end_of_month(socket.assigns.current_month)
    new_month = last_day |> Date.add(1)
    {:noreply, assign(socket, :current_month, new_month) |> load_calendar_data()}
  end

  defp load_calendar_data(socket) do
    month = socket.assigns.current_month
    {first_day, _last_day} = PlantingCalendar.month_range(month)
    weeks = PlantingCalendar.weeks_for_month(first_day)
    plantings = Plantings.list_plantings_for_month(first_day)

    # Map of date → [:planted | :harvest_due]
    events_by_date =
      Enum.reduce(plantings, %{}, fn planting, acc ->
        acc
        |> maybe_add_event(planting.planted_at, :planted)
        |> maybe_add_event(harvest_date(planting), :harvest_due)
      end)

    # Seeds with ideal window opening in this month
    ideal_seeds =
      Seeds.list_seeds()
      |> Enum.filter(fn seed ->
        case PlantingCalendar.parse_ideal_months(seed.ideal_planting_time) do
          {start_m, _end_m} -> start_m == month.month
          _ -> false
        end
      end)
      |> Enum.map(& &1.name)

    socket
    |> assign(:weeks, weeks)
    |> assign(:events_by_date, events_by_date)
    |> assign(:ideal_seeds, ideal_seeds)
    |> assign(:month_label, Calendar.strftime(month, "%B %Y"))
  end

  defp maybe_add_event(acc, nil, _type), do: acc

  defp maybe_add_event(acc, date, type) do
    Map.update(acc, date, [type], fn existing -> [type | existing] end)
  end

  defp harvest_date(%{planted_at: nil}), do: nil
  defp harvest_date(%{seed: %{maturity_days: nil}}), do: nil
  defp harvest_date(%{seed: %{maturity_days: 0}}), do: nil
  defp harvest_date(%{planted_at: planted_at, seed: %{maturity_days: days}}), do: Date.add(planted_at, days)
end
```

- [ ] **Step 5: Create the template**

Create `lib/backyard_garden_web/live/calendar/index_live.html.heex`:

```heex
<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-[#14532d]">Planting Calendar</h1>
  </div>

  <%!-- Month navigation --%>
  <div class="bg-white border border-[#bbf7d0] rounded-xl overflow-hidden">
    <div class="flex items-center justify-between px-4 py-3 border-b border-[#bbf7d0]">
      <button
        phx-click="prev_month"
        class="text-[#52b788] hover:text-[#2d6a4f] font-bold px-2 py-1 rounded hover:bg-[#f0fdf4] transition-colors"
      >
        ←
      </button>
      <h2 class="font-semibold text-[#14532d]">{@month_label}</h2>
      <button
        phx-click="next_month"
        class="text-[#52b788] hover:text-[#2d6a4f] font-bold px-2 py-1 rounded hover:bg-[#f0fdf4] transition-colors"
      >
        →
      </button>
    </div>

    <%!-- Day-of-week header --%>
    <div class="grid grid-cols-7 border-b border-[#f0fdf4]">
      <%= for day <- ~w(Mon Tue Wed Thu Fri Sat Sun) do %>
        <div class="text-center text-xs font-medium text-[#6b7280] py-2">{day}</div>
      <% end %>
    </div>

    <%!-- Calendar grid --%>
    <div class="divide-y divide-[#f0fdf4]">
      <%= for week <- @weeks do %>
        <div class="grid grid-cols-7 divide-x divide-[#f0fdf4]">
          <%= for day <- week do %>
            <div class={[
              "min-h-[72px] p-1.5 text-xs",
              if(is_nil(day), do: "bg-[#fafafa]", else: "bg-white hover:bg-[#f0fdf4]")
            ]}>
              <%= if day do %>
                <span class="font-medium text-[#374151]">{day.day}</span>
                <%!-- Ideal window marker on 1st of month --%>
                <%= if day.day == 1 and @ideal_seeds != [] do %>
                  <div class="mt-0.5 space-y-0.5">
                    <%= for seed_name <- Enum.take(@ideal_seeds, 2) do %>
                      <div class="text-[10px] text-[#2d6a4f] bg-[#dcfce7] rounded px-1 truncate">
                        🟢 {seed_name}
                      </div>
                    <% end %>
                    <%= if length(@ideal_seeds) > 2 do %>
                      <div class="text-[10px] text-[#6b7280]">+{length(@ideal_seeds) - 2} more</div>
                    <% end %>
                  </div>
                <% end %>
                <%!-- Planted / harvest dots --%>
                <%= if events = Map.get(@events_by_date, day) do %>
                  <div class="mt-0.5 flex flex-wrap gap-0.5">
                    <%= if :planted in events do %>
                      <span class="w-2 h-2 rounded-full bg-[#3b82f6] inline-block" title="Planted"></span>
                    <% end %>
                    <%= if :harvest_due in events do %>
                      <span class="w-2 h-2 rounded-full bg-[#eab308] inline-block" title="Harvest due"></span>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>

  <%!-- Legend --%>
  <div class="flex gap-4 text-xs text-[#6b7280]">
    <span class="flex items-center gap-1">
      <span class="w-2.5 h-2.5 rounded-full bg-[#3b82f6] inline-block"></span> Planted
    </span>
    <span class="flex items-center gap-1">
      <span class="w-2.5 h-2.5 rounded-full bg-[#eab308] inline-block"></span> Harvest due
    </span>
    <span class="flex items-center gap-1">
      <span class="text-[10px] text-[#2d6a4f] bg-[#dcfce7] rounded px-1">🟢</span> Ideal window opens
    </span>
  </div>
</div>
```

- [ ] **Step 6: Activate the Calendar nav link**

In `lib/backyard_garden_web/components/layouts.ex`, replace the placeholder anchor for Calendar:

```elixir
<a href="/calendar" class="text-white/50 hover:text-[#95d5b2] transition-colors">
  Calendar
</a>
```

with:

```elixir
<.nav_link href={~p"/calendar"} current_scope={@current_scope}>Calendar</.nav_link>
```

- [ ] **Step 7: Run the tests**

```bash
mix test test/backyard_garden_web/live/calendar/index_live_test.exs
```

Expected: all tests pass.

- [ ] **Step 8: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/backyard_garden_web/live/calendar \
        lib/backyard_garden_web/router.ex \
        lib/backyard_garden_web/components/layouts.ex \
        test/backyard_garden_web/live/calendar
git commit -m "feat: add Planting Calendar page with month grid and ideal window markers"
```

---

## Task 10: Zone recommendation engine

**Files:**
- Modify: `lib/backyard_garden/garden_zones/garden_zones.ex`
- Modify: `test/backyard_garden/garden_zones_test.exs`

Add `recommend_zones/1` to the GardenZones context. It takes a `%Seed{}` and returns zones sorted by match quality (best first). Match scoring: +1 for each of type, cycle, sun that match; zones with no restriction on a field always match that field.

- [ ] **Step 1: Add the failing tests**

In `test/backyard_garden/garden_zones_test.exs`, add a new describe block:

```elixir
describe "recommend_zones/1" do
  alias BackyardGarden.Seeds.Seed

  test "returns zones sorted by match score descending" do
    # Zone matching on all three dimensions
    {:ok, perfect} =
      GardenZones.create_zone(%{
        name: "Perfect Zone",
        sun_exposures: "full_sun",
        allowed_types: "Vegetable",
        allowed_cycles: "Annual"
      })

    # Zone with no type restriction — partial match
    {:ok, partial} =
      GardenZones.create_zone(%{
        name: "Partial Zone",
        sun_exposures: "full_sun",
        allowed_types: "",
        allowed_cycles: ""
      })

    seed = %Seed{type: "Vegetable", cycle: "Annual", sun_requirement: "full_sun"}
    zones = GardenZones.recommend_zones(seed)
    names = Enum.map(zones, & &1.name)

    # Perfect match comes before partial match
    assert Enum.find_index(names, &(&1 == "Perfect Zone")) <
             Enum.find_index(names, &(&1 == "Partial Zone"))
  end

  test "excludes zones that explicitly disallow the seed's type" do
    {:ok, _} =
      GardenZones.create_zone(%{
        name: "Herb Only",
        sun_exposures: "",
        allowed_types: "Herb",
        allowed_cycles: ""
      })

    seed = %Seed{type: "Vegetable", cycle: "Annual", sun_requirement: nil}
    zones = GardenZones.recommend_zones(seed)
    refute Enum.any?(zones, &(&1.name == "Herb Only"))
  end

  test "includes zones with no type restriction regardless of seed type" do
    {:ok, _} =
      GardenZones.create_zone(%{
        name: "Any Type Zone",
        sun_exposures: "",
        allowed_types: "",
        allowed_cycles: ""
      })

    seed = %Seed{type: "Vegetable", cycle: "Annual", sun_requirement: nil}
    zones = GardenZones.recommend_zones(seed)
    assert Enum.any?(zones, &(&1.name == "Any Type Zone"))
  end
end
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
mix test test/backyard_garden/garden_zones_test.exs
```

Expected: three new test failures — `recommend_zones/1` not defined.

- [ ] **Step 3: Add recommend_zones/1 to the context**

In `lib/backyard_garden/garden_zones/garden_zones.ex`, add:

```elixir
@doc """
Returns all zones that match the given seed, sorted by match score descending.

A zone is excluded only when it has explicit restrictions that conflict with the seed.
A zone with empty `allowed_types` matches any seed type.
Score = number of dimensions (type, cycle, sun) that positively match.
"""
def recommend_zones(%{type: type, cycle: cycle, sun_requirement: sun}) do
  list_zones()
  |> Enum.map(fn zone -> {zone, score_zone(zone, type, cycle, sun)} end)
  |> Enum.reject(fn {_zone, score} -> score == :excluded end)
  |> Enum.sort_by(fn {_zone, score} -> score end, :desc)
  |> Enum.map(fn {zone, _score} -> zone end)
end

defp score_zone(zone, type, cycle, sun) do
  types = parse_csv_field(zone.allowed_types)
  cycles = parse_csv_field(zone.allowed_cycles)
  suns = parse_csv_field(zone.sun_exposures)

  type_match = field_matches?(types, type)
  cycle_match = field_matches?(cycles, cycle)
  sun_match = field_matches?(suns, sun)

  cond do
    type_match == :excluded or cycle_match == :excluded or sun_match == :excluded -> :excluded
    true -> count_positives([type_match, cycle_match, sun_match])
  end
end

# Returns :match if the value is in the list, :neutral if the list is empty, :excluded otherwise.
defp field_matches?([], _value), do: :neutral
defp field_matches?(_list, nil), do: :neutral
defp field_matches?(list, value), do: if(value in list, do: :match, else: :excluded)

defp count_positives(results) do
  Enum.count(results, &(&1 == :match))
end
```

- [ ] **Step 4: Run the tests**

```bash
mix test test/backyard_garden/garden_zones_test.exs
```

Expected: all tests pass.

- [ ] **Step 5: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden/garden_zones/garden_zones.ex \
        test/backyard_garden/garden_zones_test.exs
git commit -m "feat: add recommend_zones/1 to GardenZones context"
```

---

## Task 11: Show zone recommendations in Log Planting form

**Files:**
- Modify: `lib/backyard_garden_web/live/garden/index_live.ex`
- Modify: `lib/backyard_garden_web/live/garden/index_live.html.heex`
- Modify: `test/backyard_garden_web/live/garden/index_live_test.exs`

When a seed is selected in the Log Planting form, dynamically show the recommended zones for that seed. The user can then select a zone (or leave it blank).

- [ ] **Step 1: Add the failing test**

In `test/backyard_garden_web/live/garden/index_live_test.exs`, add:

```elixir
test "shows zone recommendations when seed is selected in form", %{conn: conn} do
  alias BackyardGarden.GardenZones

  {:ok, _zone} =
    GardenZones.create_zone(%{
      name: "Sunny Raised Planters",
      sun_exposures: "full_sun",
      allowed_types: "Vegetable",
      allowed_cycles: "Annual"
    })

  seed = seed_fixture(%{name: "Beans", type: "Vegetable", cycle: "Annual", sun_requirement: "full_sun"})

  {:ok, view, _html} = live(conn, ~p"/garden")
  render_click(view, "show_form", %{})

  html =
    view
    |> form("#log-planting-form", %{"planting" => %{"seed_id" => seed.id}})
    |> render_change()

  assert html =~ "Sunny Raised Planters"
end
```

- [ ] **Step 2: Run to see it fail**

```bash
mix test test/backyard_garden_web/live/garden/index_live_test.exs
```

Expected: the new test fails.

- [ ] **Step 3: Update the LiveView to handle seed selection**

In `lib/backyard_garden_web/live/garden/index_live.ex`:

1. Add alias at top: `alias BackyardGarden.GardenZones`

2. Add `:recommended_zones` to the `mount/3` assigns:

```elixir
|> assign(:recommended_zones, [])
```

3. Add a new `handle_event` for form validation that recalculates zone recommendations when seed_id changes:

```elixir
@impl true
def handle_event("validate_planting", %{"planting" => %{"seed_id" => seed_id} = params}, socket) do
  changeset =
    %Plantings.Planting{}
    |> Plantings.change_planting(params)
    |> Map.put(:action, :validate)

  recommended_zones =
    case Seeds.get_seed(seed_id) do
      nil -> []
      seed -> GardenZones.recommend_zones(seed)
    end

  {:noreply,
   socket
   |> assign(:form, to_form(changeset))
   |> assign(:recommended_zones, recommended_zones)}
end
```

4. Add `Seeds.get_seed/1` (non-raising version) to the Seeds context — see step 4.

5. Update `handle_event("show_form", ...)` to reset recommended_zones:

```elixir
@impl true
def handle_event("show_form", _params, socket) do
  changeset = Plantings.change_planting(%Plantings.Planting{})
  {:noreply, assign(socket, show_form: true, form: to_form(changeset), recommended_zones: [])}
end
```

- [ ] **Step 4: Add Seeds.get_seed/1 to Seeds context**

In `lib/backyard_garden/seeds/seeds.ex`, add:

```elixir
@doc "Returns a single seed by id, or nil if not found."
def get_seed(id), do: Repo.get(Seed, id)
```

- [ ] **Step 5: Update the form template to show recommendations and handle validate event**

In `lib/backyard_garden_web/live/garden/index_live.html.heex`, update the form opening tag to add `phx-change`:

```heex
<.form id="log-planting-form" for={@form} phx-change="validate_planting" phx-submit="save_planting" class="grid grid-cols-1 md:grid-cols-2 gap-4">
```

Add the zone selector below the seed selector (after the seed `<div>`):

```heex
<div class="md:col-span-2">
  <label class="block text-sm font-medium text-[#374151] mb-1">Zone (optional)</label>
  <%= if @recommended_zones == [] do %>
    <p class="text-xs text-[#6b7280]">Select a seed to see zone recommendations.</p>
  <% else %>
    <.input field={@form[:zone_id]} type="select"
      options={[{"— no zone —", ""} | Enum.map(@recommended_zones, &{&1.name, &1.id})}]
      class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none bg-white" />
    <p class="text-xs text-[#52b788] mt-1">Sorted by best match for this seed.</p>
  <% end %>
</div>
```

- [ ] **Step 6: Run the tests**

```bash
mix test test/backyard_garden_web/live/garden/index_live_test.exs
```

Expected: all tests pass.

- [ ] **Step 7: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/backyard_garden_web/live/garden \
        lib/backyard_garden/seeds/seeds.ex \
        test/backyard_garden_web/live/garden
git commit -m "feat: show zone recommendations in Log Planting form based on selected seed"
```

---

## Task 12: Zone settings page

**Files:**
- Create: `lib/backyard_garden_web/live/settings/zones_live.ex`
- Create: `lib/backyard_garden_web/live/settings/zones_live.html.heex`
- Create: `test/backyard_garden_web/live/settings/zones_live_test.exs`
- Modify: `lib/backyard_garden_web/router.ex`

This page lists all zones as editable cards. Users can add, edit, and delete zones. The form is inline (no separate route needed).

- [ ] **Step 1: Write the failing tests**

Create `test/backyard_garden_web/live/settings/zones_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Settings.ZonesLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.GardenZones

  defp zone_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Zone", sun_exposures: "full_sun"}
    {:ok, zone} = GardenZones.create_zone(Map.merge(defaults, attrs))
    zone
  end

  test "renders Garden Zones heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "Garden Zones"
  end

  test "lists all zones", %{conn: conn} do
    zone_fixture(%{name: "My Zone"})
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "My Zone"
  end

  test "shows Add Zone button", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "Add Zone"
  end

  test "creates a new zone via the form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => "Fruit Patch", "sun_exposures" => "full_sun"}})
      |> render_submit()

    assert html =~ "Fruit Patch"
  end

  test "deletes a zone", %{conn: conn} do
    zone = zone_fixture(%{name: "Delete Me"})
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    html = render_click(view, "delete_zone", %{"id" => zone.id})
    refute html =~ "Delete Me"
  end

  test "edits a zone", %{conn: conn} do
    zone = zone_fixture(%{name: "Old Name"})
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "edit_zone", %{"id" => zone.id})

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => "New Name"}})
      |> render_submit()

    assert html =~ "New Name"
    refute html =~ "Old Name"
  end
end
```

- [ ] **Step 2: Run to see it fail**

```bash
mix test test/backyard_garden_web/live/settings/zones_live_test.exs
```

Expected: failure — no route for `/settings/zones`.

- [ ] **Step 3: Add the route**

In `lib/backyard_garden_web/router.ex`:

```elixir
live "/settings/zones", Settings.ZonesLive, :index
```

- [ ] **Step 4: Create the LiveView module**

Create `lib/backyard_garden_web/live/settings/zones_live.ex`:

```elixir
defmodule BackyardGardenWeb.Settings.ZonesLive do
  @moduledoc """
  LiveView for managing garden zones — add, edit, and delete zones.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Garden Zones")
     |> assign(:zones, GardenZones.list_zones())
     |> assign(:editing_zone, nil)
     |> assign(:show_form, false)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_event("new_zone", _params, socket) do
    changeset = GardenZone.changeset(%GardenZone{}, %{})
    {:noreply, assign(socket, editing_zone: nil, show_form: true, form: to_form(changeset))}
  end

  @impl true
  def handle_event("edit_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    changeset = GardenZone.changeset(zone, %{})
    {:noreply, assign(socket, editing_zone: zone, show_form: true, form: to_form(changeset))}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, editing_zone: nil, show_form: false, form: nil)}
  end

  @impl true
  def handle_event("save_zone", %{"zone" => params}, socket) do
    result =
      case socket.assigns.editing_zone do
        nil -> GardenZones.create_zone(params)
        zone -> GardenZones.update_zone(zone, params)
      end

    case result do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> assign(:zones, GardenZones.list_zones())
         |> assign(:editing_zone, nil)
         |> assign(:show_form, false)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    {:ok, _} = GardenZones.delete_zone(zone)
    {:noreply, assign(socket, :zones, GardenZones.list_zones())}
  end
end
```

- [ ] **Step 5: Create the template**

Create `lib/backyard_garden_web/live/settings/zones_live.html.heex`:

```heex
<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-[#14532d]">Garden Zones</h1>
    <button
      phx-click="new_zone"
      class="bg-[#2d6a4f] text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-[#1a3a2a] transition-colors"
    >
      + Add Zone
    </button>
  </div>

  <%!-- Add/Edit form --%>
  <%= if @show_form do %>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-6 space-y-4">
      <h2 class="text-lg font-semibold text-[#14532d]">
        {if @editing_zone, do: "Edit Zone", else: "Add Zone"}
      </h2>
      <.form id="zone-form" for={@form} phx-submit="save_zone" class="space-y-3">
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Name</label>
          <.input field={@form[:name]} type="text"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">Description</label>
          <.input field={@form[:description]} type="text"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">
            Sun Exposures <span class="font-normal text-[#6b7280]">(comma-separated: full_sun, partial_sun, shade_tolerant)</span>
          </label>
          <.input field={@form[:sun_exposures]} type="text"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">
            Allowed Types <span class="font-normal text-[#6b7280]">(comma-separated, or blank for any)</span>
          </label>
          <.input field={@form[:allowed_types]} type="text"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div>
          <label class="block text-sm font-medium text-[#374151] mb-1">
            Allowed Cycles <span class="font-normal text-[#6b7280]">(comma-separated, or blank for any)</span>
          </label>
          <.input field={@form[:allowed_cycles]} type="text"
            class="w-full rounded-lg border border-[#bbf7d0] px-3 py-2 text-sm focus:border-[#52b788] focus:outline-none" />
        </div>
        <div class="flex gap-3">
          <button type="submit" class="bg-[#2d6a4f] text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-[#1a3a2a] transition-colors">
            Save
          </button>
          <button type="button" phx-click="cancel_form" class="rounded-lg px-4 py-2 text-sm font-medium border border-[#bbf7d0] text-[#374151] hover:bg-[#f0fdf4] transition-colors">
            Cancel
          </button>
        </div>
      </.form>
    </div>
  <% end %>

  <%!-- Zone cards --%>
  <%= if Enum.empty?(@zones) do %>
    <p class="text-sm text-[#6b7280]">No zones yet. Add one to get started.</p>
  <% else %>
    <div class="space-y-3">
      <%= for zone <- @zones do %>
        <div class="bg-white border border-[#bbf7d0] rounded-xl p-4">
          <div class="flex items-start justify-between gap-4">
            <div class="space-y-1">
              <p class="font-semibold text-[#14532d]">{zone.name}</p>
              <%= if zone.description && zone.description != "" do %>
                <p class="text-sm text-[#6b7280]">{zone.description}</p>
              <% end %>
              <div class="flex flex-wrap gap-3 text-xs text-[#374151] mt-1">
                <span>
                  <span class="text-[#52b788] uppercase tracking-wide font-semibold">Sun:</span>
                  {if zone.sun_exposures && zone.sun_exposures != "", do: zone.sun_exposures, else: "Any"}
                </span>
                <span>
                  <span class="text-[#52b788] uppercase tracking-wide font-semibold">Types:</span>
                  {if zone.allowed_types && zone.allowed_types != "", do: zone.allowed_types, else: "Any"}
                </span>
                <span>
                  <span class="text-[#52b788] uppercase tracking-wide font-semibold">Cycles:</span>
                  {if zone.allowed_cycles && zone.allowed_cycles != "", do: zone.allowed_cycles, else: "Any"}
                </span>
              </div>
            </div>
            <div class="flex gap-2 shrink-0">
              <button
                phx-click="edit_zone"
                phx-value-id={zone.id}
                class="text-xs rounded-lg border border-[#bbf7d0] px-3 py-1.5 text-[#374151] hover:bg-[#f0fdf4] transition-colors"
              >
                Edit
              </button>
              <button
                phx-click="delete_zone"
                phx-value-id={zone.id}
                data-confirm="Delete this zone?"
                class="text-xs rounded-lg border border-red-200 px-3 py-1.5 text-red-600 hover:bg-red-50 transition-colors"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Run the tests**

```bash
mix test test/backyard_garden_web/live/settings/zones_live_test.exs
```

Expected: all tests pass.

- [ ] **Step 7: Run full suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/backyard_garden_web/live/settings \
        lib/backyard_garden_web/router.ex \
        test/backyard_garden_web/live/settings
git commit -m "feat: add Zone settings page at /settings/zones"
```

---

## Task 13: Final verification and Plan.md update

- [ ] **Step 1: Run the complete test suite with linting**

```bash
mix precommit
```

Expected: all checks pass — compile, format, credo, deps, tests.

- [ ] **Step 2: Run the security scan**

```bash
mix sobelow
```

Expected: no warnings (CSP warning fixed in Task 1).

- [ ] **Step 3: Smoke-test the running app**

```bash
mix phx.server
```

Visit each page and verify:
- `/seeds` — seed library loads, edit link works from detail page
- `/seeds/:id/edit` — form prefills, save redirects back to show
- `/garden` — three sections shown, Log Planting form opens, zone recommendations appear when seed is selected
- `/calendar` — month grid renders, prev/next navigation works
- `/settings/zones` — default zones listed (if script was run), add/edit/delete work

- [ ] **Step 4: Update Plan.md to mark Phase 2 tasks complete**

In `Plan.md`, under `### Phase 2 — Garden & Planting Tracking`, change all `- [ ]` to `- [x]` for tasks 2.1–2.10, and add `✅ Complete` to the phase heading.

- [ ] **Step 5: Final commit**

```bash
git add Plan.md
git commit -m "docs: mark Phase 2 complete in Plan.md"
```
