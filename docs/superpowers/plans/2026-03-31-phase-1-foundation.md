# Phase 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap a Phoenix + SQLite app with a browsable, searchable seed library populated from `Seed Planting 2026.csv`.

**Architecture:** Phoenix 1.7 with LiveView for the seed library UI. Ecto + ecto_sqlite3 for the database. Seeds context encapsulates all database access. No auth yet — the app is local-only in this phase.

**Tech Stack:** Elixir/OTP, Phoenix 1.7, Phoenix LiveView, Ecto, ecto_sqlite3, Tailwind CSS, NimbleCSV.

**Deliverable:** Running `mix phx.server` serves a mobile-responsive seed library at `http://localhost:4000/seeds` with live search and filtering by type, brand, and cycle.

---

## File Map

Files created or modified by this plan:

```
backyard_garden/
├── mix.exs                                          # MODIFY: add ecto_sqlite3, nimble_csv
├── config/
│   ├── config.exs                                   # MODIFY: Ecto repo config
│   ├── dev.exs                                      # MODIFY: SQLite dev database path
│   └── test.exs                                     # MODIFY: SQLite test database path
├── lib/
│   ├── backyard_garden/
│   │   ├── repo.ex                                  # generated
│   │   └── seeds/
│   │       ├── seed.ex                              # CREATE: Ecto schema
│   │       └── seeds.ex                             # CREATE: context (list, get, filter)
│   └── backyard_garden_web/
│       ├── router.ex                                # MODIFY: add /seeds and /seeds/:id routes
│       ├── components/
│       │   └── layouts/
│       │       └── root.html.heex                   # MODIFY: add nav bar
│       └── live/
│           └── seeds/
│               ├── index_live.ex                    # CREATE: seed library LiveView
│               ├── index_live.html.heex             # CREATE: seed list + filter form
│               ├── show_live.ex                     # CREATE: seed detail LiveView
│               └── show_live.html.heex              # CREATE: seed detail template
├── priv/
│   └── repo/
│       ├── migrations/
│       │   └── 20260331000001_create_seeds.exs      # CREATE: seeds table migration
│       └── seeds.exs                                # CREATE: CSV import script
└── test/
    ├── backyard_garden/
    │   └── seeds_test.exs                           # CREATE: context unit tests
    └── backyard_garden_web/
        └── live/
            └── seeds/
                ├── index_live_test.exs              # CREATE: LiveView integration tests
                └── show_live_test.exs               # CREATE: show page tests
```

---

## Prerequisites

You need Elixir 1.16+ and Erlang/OTP 26+. The easiest way is via `asdf`:

```bash
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.2
asdf install elixir 1.18.2-otp-27
asdf global erlang 27.2
asdf global elixir 1.18.2-otp-27
```

Verify:
```bash
elixir --version
# Erlang/OTP 27 [erts-15.2] ... Elixir 1.18.2 (compiled with Erlang/OTP 27)
```

Install the Phoenix project generator:
```bash
mix archive.install hex phx_new
```

---

## Task 1: Initialise the Phoenix Project

**Files:** `mix.exs`, `config/`, `lib/`, `test/` (all generated)

- [ ] **Step 1.1: Generate the project**

Run from `/Users/simon/workspace/BackyardGarden/`:

```bash
mix phx.new . --app backyard_garden --binary-id --no-mailer
```

When prompted "The directory ... already has files, are you sure you want to proceed?", type `Y`.

`--binary-id` configures UUID primary keys throughout (matches our data model).
`--no-mailer` skips Swoosh email setup (not needed in Phase 1).

Expected output ends with:
```
We are almost there! The following steps are missing:

    $ cd .
    $ mix ecto.create
```

- [ ] **Step 1.2: Install dependencies**

```bash
mix deps.get
```

- [ ] **Step 1.3: Verify the app starts**

```bash
mix phx.server
```

Visit `http://localhost:4000`. You should see the default Phoenix welcome page. Stop with `Ctrl+C`.

- [ ] **Step 1.4: Commit the generated project**

```bash
git init
echo "_build/" >> .gitignore
echo "deps/" >> .gitignore
echo "*.db" >> .gitignore
echo "*.db-shm" >> .gitignore
echo "*.db-wal" >> .gitignore
git add -A
git commit -m "feat: init Phoenix project with binary-id and no-mailer"
```

---

## Task 2: Configure SQLite

Phoenix generates with PostgreSQL by default. We need to swap it out.

**Files:** `mix.exs`, `config/config.exs`, `config/dev.exs`, `config/test.exs`

- [ ] **Step 2.1: Replace the Postgres adapter with ecto_sqlite3**

In `mix.exs`, find the `deps` function and replace `{:postgrex, ">= 0.0.0"}` with:

```elixir
{:ecto_sqlite3, "~> 0.17"},
{:nimble_csv, "~> 1.2"},
```

The full `deps` list should now include (among the generated entries):
```elixir
{:phoenix, "~> 1.7"},
{:phoenix_ecto, "~> 4.6"},
{:ecto_sqlite3, "~> 0.17"},
{:nimble_csv, "~> 1.2"},
{:phoenix_html, "~> 4.1"},
{:phoenix_live_reload, "~> 1.2", only: :dev},
{:phoenix_live_view, "~> 1.0"},
{:floki, ">= 0.30.0", only: :test},
{:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
{:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
{:telemetry_metrics, "~> 1.0"},
{:telemetry_poller, "~> 1.0"},
{:gettext, "~> 0.26"},
{:jason, "~> 1.2"},
{:dns_cluster, "~> 0.1.1"},
{:bandit, "~> 1.5"},
```

- [ ] **Step 2.2: Update the Repo module**

In `lib/backyard_garden/repo.ex`, change the adapter:

```elixir
defmodule BackyardGarden.Repo do
  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: Ecto.Adapters.SQLite3
end
```

- [ ] **Step 2.3: Update config/config.exs**

Replace the database config block (the `config :backyard_garden, BackyardGarden.Repo` section) with:

```elixir
config :backyard_garden, BackyardGarden.Repo,
  database: Path.expand("../priv/repo/backyard_garden.db", __DIR__),
  pool_size: 5
```

- [ ] **Step 2.4: Update config/dev.exs**

Replace the database config block with:

```elixir
config :backyard_garden, BackyardGarden.Repo,
  database: Path.expand("../priv/repo/backyard_garden_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
```

- [ ] **Step 2.5: Update config/test.exs**

Replace the database config block with:

```elixir
config :backyard_garden, BackyardGarden.Repo,
  database: Path.expand("../priv/repo/backyard_garden_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

- [ ] **Step 2.6: Fetch new deps and create the database**

```bash
mix deps.get
mix ecto.create
```

Expected:
```
The database for BackyardGarden.Repo has been created
```

- [ ] **Step 2.7: Commit**

```bash
git add mix.exs mix.lock config/ lib/backyard_garden/repo.ex
git commit -m "feat: configure ecto_sqlite3 adapter"
```

---

## Task 3: Seeds Migration and Schema

**Files:**
- Create: `priv/repo/migrations/20260331000001_create_seeds.exs`
- Create: `lib/backyard_garden/seeds/seed.ex`

- [ ] **Step 3.1: Generate the migration**

```bash
mix ecto.gen.migration create_seeds
```

This creates `priv/repo/migrations/YYYYMMDDHHMMSS_create_seeds.exs`. Open it and replace the `change/0` body with:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreateSeeds do
  use Ecto.Migration

  def change do
    create table(:seeds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :brand, :string
      add :type, :string
      add :cycle, :string
      add :planting_method, :string
      add :ideal_planting_time, :string
      add :maturity_days, :integer
      add :sun_requirement, :string
      add :source_url, :string
      add :notes, :text

      timestamps()
    end

    create index(:seeds, [:name])
    create index(:seeds, [:type])
    create index(:seeds, [:brand])
    create index(:seeds, [:cycle])
  end
end
```

- [ ] **Step 3.2: Run the migration**

```bash
mix ecto.migrate
```

Expected:
```
[info] == Running ... CreateSeeds.change/0 forward
[info] create table seeds
[info] create index seeds_name_index
...
[info] == Migrated ... in 0.0s
```

- [ ] **Step 3.3: Create the Seed schema**

Create `lib/backyard_garden/seeds/seed.ex`:

```elixir
defmodule BackyardGarden.Seeds.Seed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "seeds" do
    field :name, :string
    field :brand, :string
    field :type, :string
    field :cycle, :string
    field :planting_method, :string
    field :ideal_planting_time, :string
    field :maturity_days, :integer
    field :sun_requirement, :string
    field :source_url, :string
    field :notes, :string

    timestamps()
  end

  def changeset(seed, attrs) do
    seed
    |> cast(attrs, [
      :name, :brand, :type, :cycle, :planting_method,
      :ideal_planting_time, :maturity_days, :sun_requirement,
      :source_url, :notes
    ])
    |> validate_required([:name])
  end
end
```

- [ ] **Step 3.4: Commit**

```bash
git add priv/repo/migrations/ lib/backyard_garden/seeds/seed.ex
git commit -m "feat: add seeds migration and schema"
```

---

## Task 4: Seeds Context

The context is the public API for all seed-related database operations. All LiveViews call this module — never Repo directly.

**Files:**
- Create: `lib/backyard_garden/seeds/seeds.ex`
- Create: `test/backyard_garden/seeds_test.exs`

- [ ] **Step 4.1: Write the failing tests**

Create `test/backyard_garden/seeds_test.exs`:

```elixir
defmodule BackyardGarden.SeedsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Seeds
  alias BackyardGarden.Seeds.Seed

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  describe "list_seeds/1" do
    test "returns all seeds ordered by name when no filters" do
      seed_fixture(%{name: "Zucchini", type: "Vegetable"})
      seed_fixture(%{name: "Basil"})
      seeds = Seeds.list_seeds(%{})
      assert Enum.map(seeds, & &1.name) == ["Basil", "Zucchini"]
    end

    test "filters by type" do
      seed_fixture(%{name: "Basil", type: "Herb"})
      seed_fixture(%{name: "Carrots", type: "Vegetable"})
      seeds = Seeds.list_seeds(%{type: "Herb"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Basil"
    end

    test "filters by brand" do
      seed_fixture(%{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(%{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(%{brand: "West Coast Seeds"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "filters by cycle" do
      seed_fixture(%{name: "Basil", cycle: "Annual"})
      seed_fixture(%{name: "Echinacea", cycle: "Perennial"})
      seeds = Seeds.list_seeds(%{cycle: "Perennial"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Echinacea"
    end

    test "searches by name (case-insensitive)" do
      seed_fixture(%{name: "Purple Basil"})
      seed_fixture(%{name: "Carrots"})
      seeds = Seeds.list_seeds(%{search: "basil"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Purple Basil"
    end

    test "searches by brand" do
      seed_fixture(%{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(%{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(%{search: "west coast"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "empty string filters are ignored" do
      seed_fixture(%{name: "Basil"})
      seed_fixture(%{name: "Carrots"})
      seeds = Seeds.list_seeds(%{type: "", brand: "", cycle: "", search: ""})
      assert length(seeds) == 2
    end
  end

  describe "get_seed!/1" do
    test "returns the seed with given id" do
      seed = seed_fixture()
      assert Seeds.get_seed!(seed.id).name == seed.name
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Seeds.get_seed!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_types/0" do
    test "returns distinct non-nil types sorted" do
      seed_fixture(%{type: "Vegetable"})
      seed_fixture(%{type: "Herb"})
      seed_fixture(%{type: "Herb"})
      assert Seeds.list_types() == ["Herb", "Vegetable"]
    end
  end

  describe "list_brands/0" do
    test "returns distinct non-nil brands sorted" do
      seed_fixture(%{brand: "West Coast Seeds"})
      seed_fixture(%{brand: "Metchosin Farm"})
      assert Seeds.list_brands() == ["Metchosin Farm", "West Coast Seeds"]
    end
  end

  describe "list_cycles/0" do
    test "returns distinct non-nil cycles sorted" do
      seed_fixture(%{cycle: "Perennial"})
      seed_fixture(%{cycle: "Annual"})
      assert Seeds.list_cycles() == ["Annual", "Perennial"]
    end
  end

  describe "create_seed/1" do
    test "creates a seed with valid attrs" do
      attrs = %{name: "Basil", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
      assert {:ok, %{name: "Basil"}} = Seeds.create_seed(attrs)
    end

    test "returns error changeset when name is missing" do
      assert {:error, changeset} = Seeds.create_seed(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
```

- [ ] **Step 4.2: Run tests to verify they fail**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected: compilation error — `BackyardGarden.Seeds` module does not exist yet.

- [ ] **Step 4.3: Create the Seeds context**

Create `lib/backyard_garden/seeds/seeds.ex`:

```elixir
defmodule BackyardGarden.Seeds do
  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Seeds.Seed

  @doc "Returns all seeds matching the given filters, sorted by name."
  def list_seeds(filters \\ %{}) do
    Seed
    |> filter_by(:type, filters[:type])
    |> filter_by(:brand, filters[:brand])
    |> filter_by(:cycle, filters[:cycle])
    |> filter_by_search(filters[:search])
    |> order_by([s], s.name)
    |> Repo.all()
  end

  @doc "Returns a single seed by id. Raises Ecto.NoResultsError if not found."
  def get_seed!(id), do: Repo.get!(Seed, id)

  @doc "Creates a seed. Returns {:ok, seed} or {:error, changeset}."
  def create_seed(attrs) do
    %Seed{}
    |> Seed.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Returns a sorted list of distinct seed types present in the database."
  def list_types do
    Seed
    |> where([s], not is_nil(s.type) and s.type != "")
    |> select([s], s.type)
    |> distinct(true)
    |> order_by([s], s.type)
    |> Repo.all()
  end

  @doc "Returns a sorted list of distinct seed brands present in the database."
  def list_brands do
    Seed
    |> where([s], not is_nil(s.brand) and s.brand != "")
    |> select([s], s.brand)
    |> distinct(true)
    |> order_by([s], s.brand)
    |> Repo.all()
  end

  @doc "Returns a sorted list of distinct seed cycles present in the database."
  def list_cycles do
    Seed
    |> where([s], not is_nil(s.cycle) and s.cycle != "")
    |> select([s], s.cycle)
    |> distinct(true)
    |> order_by([s], s.cycle)
    |> Repo.all()
  end

  # --- Private query helpers ---

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, _field, ""), do: query
  defp filter_by(query, field, value), do: where(query, [s], field(s, ^field) == ^value)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query
  defp filter_by_search(query, search) do
    term = "%#{String.downcase(search)}%"
    where(
      query,
      [s],
      like(fragment("lower(?)", s.name), ^term) or
        like(fragment("lower(?)", s.brand), ^term)
    )
  end
end
```

- [ ] **Step 4.4: Run tests and verify they pass**

```bash
mix test test/backyard_garden/seeds_test.exs
```

Expected:
```
..............
14 tests, 0 failures
```

- [ ] **Step 4.5: Commit**

```bash
git add lib/backyard_garden/seeds/ test/backyard_garden/seeds_test.exs
git commit -m "feat: add Seeds context with filtering and search"
```

---

## Task 5: CSV Import

This creates a Mix task that reads `Seed Planting 2026.csv` from the project root and inserts seeds into the database. It is idempotent — running it twice will not create duplicates.

**Files:**
- Modify: `priv/repo/seeds.exs`

- [ ] **Step 5.1: Write the seeds.exs script**

Replace the contents of `priv/repo/seeds.exs` with:

```elixir
# priv/repo/seeds.exs
# Run with: mix run priv/repo/seeds.exs
#
# Idempotent: skips seeds that already exist (matched by name + brand).

alias BackyardGarden.Repo
alias BackyardGarden.Seeds.Seed

NimbleCSV.define(SeedCSVParser, separator: ",", escape: "\"")

csv_path = Path.join(File.cwd!(), "Seed Planting 2026.csv")

unless File.exists?(csv_path) do
  IO.puts("ERROR: #{csv_path} not found. Make sure you're running from the project root.")
  System.halt(1)
end

defp parse_maturity(str) do
  case Regex.run(~r/(\d+)/, str || "") do
    [_, n] -> String.to_integer(n)
    nil -> nil
  end
end

csv_path
|> File.stream!()
|> SeedCSVParser.parse_stream(skip_headers: true)
|> Enum.each(fn row ->
  [name, brand, type, cycle, _when_bought, planting_method, ideal_planting_time,
   _actually_planted, maturity | _rest] = row ++ List.duplicate("", 11)

  attrs = %{
    name:                String.trim(name),
    brand:               String.trim(brand),
    type:                String.trim(type),
    cycle:               String.trim(cycle),
    planting_method:     String.trim(planting_method),
    ideal_planting_time: String.trim(ideal_planting_time),
    maturity_days:       parse_maturity(String.trim(maturity))
  }

  case Repo.get_by(Seed, name: attrs.name, brand: attrs.brand) do
    nil ->
      case Seed.changeset(%Seed{}, attrs) |> Repo.insert() do
        {:ok, seed} -> IO.puts("  + Inserted: #{seed.name}")
        {:error, cs} -> IO.puts("  ! Failed: #{attrs.name} — #{inspect(cs.errors)}")
      end
    _existing ->
      IO.puts("  ~ Skipped (exists): #{attrs.name}")
  end
end)

IO.puts("\nDone. Total seeds: #{Repo.aggregate(Seed, :count, :id)}")
```

Note: `defp` in a script file is not valid Elixir (no enclosing module). The parse_maturity logic must be inline. Replace with:

```elixir
# priv/repo/seeds.exs
alias BackyardGarden.Repo
alias BackyardGarden.Seeds.Seed

NimbleCSV.define(SeedCSVParser, separator: ",", escape: "\"")

csv_path = Path.join(File.cwd!(), "Seed Planting 2026.csv")

unless File.exists?(csv_path) do
  IO.puts("ERROR: #{csv_path} not found.")
  System.halt(1)
end

csv_path
|> File.stream!()
|> SeedCSVParser.parse_stream(skip_headers: true)
|> Enum.each(fn row ->
  padded = row ++ List.duplicate("", 11)
  [name, brand, type, cycle, _when_bought, planting_method, ideal_planting_time,
   _actually_planted, maturity | _rest] = padded

  maturity_days =
    case Regex.run(~r/(\d+)/, maturity) do
      [_, n] -> String.to_integer(n)
      nil -> nil
    end

  attrs = %{
    name:                String.trim(name),
    brand:               String.trim(brand),
    type:                String.trim(type),
    cycle:               String.trim(cycle),
    planting_method:     String.trim(planting_method),
    ideal_planting_time: String.trim(ideal_planting_time),
    maturity_days:       maturity_days
  }

  case Repo.get_by(Seed, name: attrs.name, brand: attrs.brand) do
    nil ->
      case Seed.changeset(%Seed{}, attrs) |> Repo.insert() do
        {:ok, seed} -> IO.puts("  + Inserted: #{seed.name}")
        {:error, cs} -> IO.puts("  ! Failed: #{attrs.name} — #{inspect(cs.errors)}")
      end
    _existing ->
      IO.puts("  ~ Skipped (exists): #{attrs.name}")
  end
end)

IO.puts("\nDone. Total seeds: #{Repo.aggregate(Seed, :count, :id)}")
```

- [ ] **Step 5.2: Run the import**

```bash
mix run priv/repo/seeds.exs
```

Expected output (62 lines of `+ Inserted:` followed by):
```
  + Inserted: Anise Hysop
  + Inserted: Beets - Blend
  ...
  + Inserted: Zucchini - Noche

Done. Total seeds: 62
```

- [ ] **Step 5.3: Verify by running again (idempotency check)**

```bash
mix run priv/repo/seeds.exs
```

Expected: all 62 lines show `~ Skipped (exists):`, count still 62.

- [ ] **Step 5.4: Commit**

```bash
git add priv/repo/seeds.exs
git commit -m "feat: CSV import script for seed data (idempotent)"
```

---

## Task 6: Responsive Layout

Adds a top navigation bar and responsive shell that all pages will use.

**Files:**
- Modify: `lib/backyard_garden_web/components/layouts/root.html.heex`
- Modify: `lib/backyard_garden_web/components/layouts/app.html.heex`

- [ ] **Step 6.1: Update root.html.heex**

Replace the entire contents of `lib/backyard_garden_web/components/layouts/root.html.heex` with:

```heex
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · BackyardGarden">
      <%= assigns[:page_title] || "BackyardGarden" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="h-full bg-stone-50 text-stone-900 antialiased">
    <%= @inner_content %>
  </body>
</html>
```

- [ ] **Step 6.2: Update app.html.heex**

Replace the entire contents of `lib/backyard_garden_web/components/layouts/app.html.heex` with:

```heex
<header class="bg-green-800 text-white shadow-md">
  <nav class="mx-auto max-w-5xl px-4 py-3 flex items-center justify-between">
    <a href="/" class="flex items-center gap-2 text-lg font-semibold hover:text-green-200">
      <span>🌱</span>
      <span>BackyardGarden</span>
    </a>
    <div class="flex items-center gap-6 text-sm font-medium">
      <a href={~p"/seeds"} class="hover:text-green-200 transition-colors">Seeds</a>
      <a href={~p"/garden"} class="hover:text-green-200 transition-colors">My Garden</a>
      <a href={~p"/calendar"} class="hover:text-green-200 transition-colors">Calendar</a>
    </div>
  </nav>
</header>

<main class="mx-auto max-w-5xl px-4 py-8">
  <.flash_group flash={@flash} />
  <%= @inner_content %>
</main>
```

- [ ] **Step 6.3: Verify the layout renders**

```bash
mix phx.server
```

Visit `http://localhost:4000`. The green nav bar should appear at the top. Stop with `Ctrl+C`.

- [ ] **Step 6.4: Commit**

```bash
git add lib/backyard_garden_web/components/layouts/
git commit -m "feat: responsive nav layout with Tailwind"
```

---

## Task 7: Seed Library LiveView

The seed library page at `/seeds` — a filterable, searchable table of all seeds.

**Files:**
- Modify: `lib/backyard_garden_web/router.ex`
- Create: `lib/backyard_garden_web/live/seeds/index_live.ex`
- Create: `lib/backyard_garden_web/live/seeds/index_live.html.heex`
- Create: `test/backyard_garden_web/live/seeds/index_live_test.exs`

- [ ] **Step 7.1: Write the failing tests**

Create `test/backyard_garden_web/live/seeds/index_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Seeds.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds

  setup do
    {:ok, basil}     = Seeds.create_seed(%{name: "Basil", brand: "Metchosin Farm", type: "Herb", cycle: "Annual", ideal_planting_time: "Spring"})
    {:ok, carrots}   = Seeds.create_seed(%{name: "Carrots", brand: "West Coast Seeds", type: "Vegetable", cycle: "Annual", ideal_planting_time: "Early Spring"})
    {:ok, echinacea} = Seeds.create_seed(%{name: "Echinacea", brand: "Metchosin Farm", type: "Herb", cycle: "Perennial", ideal_planting_time: "Early Spring"})
    %{basil: basil, carrots: carrots, echinacea: echinacea}
  end

  test "renders all seeds", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "Basil"
    assert html =~ "Carrots"
    assert html =~ "Echinacea"
  end

  test "shows seed count", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "3 seeds"
  end

  test "filters by type via form change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "Herb", "brand" => "", "cycle" => "", "search" => ""})
      |> render_change()

    assert html =~ "Basil"
    assert html =~ "Echinacea"
    refute html =~ "Carrots"
    assert html =~ "2 seeds"
  end

  test "filters by brand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "", "brand" => "West Coast Seeds", "cycle" => "", "search" => ""})
      |> render_change()

    assert html =~ "Carrots"
    refute html =~ "Basil"
  end

  test "filters by cycle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "", "brand" => "", "cycle" => "Perennial", "search" => ""})
      |> render_change()

    assert html =~ "Echinacea"
    refute html =~ "Basil"
    refute html =~ "Carrots"
  end

  test "searches by name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "", "brand" => "", "cycle" => "", "search" => "carr"})
      |> render_change()

    assert html =~ "Carrots"
    refute html =~ "Basil"
  end

  test "each row links to seed detail", %{conn: conn, basil: basil} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ ~p"/seeds/#{basil.id}"
  end
end
```

- [ ] **Step 7.2: Run to verify tests fail**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: error — route `/seeds` does not exist.

- [ ] **Step 7.3: Add routes**

In `lib/backyard_garden_web/router.ex`, find the `scope "/"` block that uses the `:browser` pipeline and add:

```elixir
scope "/", BackyardGardenWeb do
  pipe_through :browser

  get "/", PageController, :home

  live "/seeds", Seeds.IndexLive, :index
  live "/seeds/:id", Seeds.ShowLive, :show
end
```

- [ ] **Step 7.4: Create the IndexLive module**

Create `lib/backyard_garden_web/live/seeds/index_live.ex`:

```elixir
defmodule BackyardGardenWeb.Seeds.IndexLive do
  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_filters(%{})
     |> assign(:types, Seeds.list_types())
     |> assign(:brands, Seeds.list_brands())
     |> assign(:cycles, Seeds.list_cycles())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      type:   params["type"]   || "",
      brand:  params["brand"]  || "",
      cycle:  params["cycle"]  || "",
      search: params["search"] || ""
    }
    {:noreply, assign_filters(socket, filters)}
  end

  defp assign_filters(socket, filters) do
    seeds = Seeds.list_seeds(filters)
    socket
    |> assign(:seeds, seeds)
    |> assign(:seed_count, length(seeds))
    |> assign(:filters, filters)
  end
end
```

- [ ] **Step 7.5: Create the index template**

Create `lib/backyard_garden_web/live/seeds/index_live.html.heex`:

```heex
<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-stone-800">Seed Library</h1>
    <span class="text-sm text-stone-500"><%= @seed_count %> seeds</span>
  </div>

  <form id="filter-form" phx-change="filter" class="flex flex-wrap gap-3">
    <input
      type="text"
      name="search"
      value={@filters[:search]}
      placeholder="Search seeds..."
      class="flex-1 min-w-[180px] rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:outline-none"
    />
    <select name="type" class="rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:outline-none">
      <option value="">All types</option>
      <%= for type <- @types do %>
        <option value={type} selected={@filters[:type] == type}><%= type %></option>
      <% end %>
    </select>
    <select name="brand" class="rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:outline-none">
      <option value="">All brands</option>
      <%= for brand <- @brands do %>
        <option value={brand} selected={@filters[:brand] == brand}><%= brand %></option>
      <% end %>
    </select>
    <select name="cycle" class="rounded-lg border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:outline-none">
      <option value="">All cycles</option>
      <%= for cycle <- @cycles do %>
        <option value={cycle} selected={@filters[:cycle] == cycle}><%= cycle %></option>
      <% end %>
    </select>
  </form>

  <div class="overflow-x-auto rounded-xl border border-stone-200 shadow-sm">
    <table class="w-full text-sm">
      <thead class="bg-stone-100 text-stone-600 text-left">
        <tr>
          <th class="px-4 py-3 font-medium">Name</th>
          <th class="px-4 py-3 font-medium hidden sm:table-cell">Type</th>
          <th class="px-4 py-3 font-medium hidden md:table-cell">Brand</th>
          <th class="px-4 py-3 font-medium hidden sm:table-cell">Cycle</th>
          <th class="px-4 py-3 font-medium">Plant in</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-stone-100">
        <%= for seed <- @seeds do %>
          <tr class="hover:bg-stone-50 transition-colors">
            <td class="px-4 py-3">
              <a href={~p"/seeds/#{seed.id}"} class="font-medium text-green-700 hover:underline">
                <%= seed.name %>
              </a>
            </td>
            <td class="px-4 py-3 text-stone-600 hidden sm:table-cell"><%= seed.type %></td>
            <td class="px-4 py-3 text-stone-500 hidden md:table-cell"><%= seed.brand %></td>
            <td class="px-4 py-3 text-stone-500 hidden sm:table-cell"><%= seed.cycle %></td>
            <td class="px-4 py-3 text-stone-600"><%= seed.ideal_planting_time %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

- [ ] **Step 7.6: Run tests and verify they pass**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected:
```
.........
9 tests, 0 failures
```

- [ ] **Step 7.7: Start the server and verify in a browser**

```bash
mix phx.server
```

Visit `http://localhost:4000/seeds`. You should see the full list of 62 seeds with working search and filter dropdowns. Try:
- Typing "bean" in the search box — should live-filter to bean varieties
- Selecting "Herb" from the Type dropdown — should show only herbs
- Resizing the browser window — columns hide on small screens

- [ ] **Step 7.8: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/ lib/backyard_garden_web/router.ex
git add test/backyard_garden_web/live/seeds/index_live_test.exs
git commit -m "feat: seed library LiveView with live search and filter"
```

---

## Task 8: Seed Detail LiveView

The detail page at `/seeds/:id` showing all information about a single seed.

**Files:**
- Create: `lib/backyard_garden_web/live/seeds/show_live.ex`
- Create: `lib/backyard_garden_web/live/seeds/show_live.html.heex`
- Create: `test/backyard_garden_web/live/seeds/show_live_test.exs`

- [ ] **Step 8.1: Write the failing tests**

Create `test/backyard_garden_web/live/seeds/show_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Seeds.ShowLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds

  setup do
    {:ok, seed} =
      Seeds.create_seed(%{
        name: "Purple Basil",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Annual",
        planting_method: "Seedlings",
        ideal_planting_time: "Late April/Early May",
        maturity_days: 60,
        notes: "Great companion plant"
      })

    %{seed: seed}
  end

  test "renders seed name and details", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")

    assert html =~ "Purple Basil"
    assert html =~ "Metchosin Farm"
    assert html =~ "Herb"
    assert html =~ "Annual"
    assert html =~ "Seedlings"
    assert html =~ "Late April/Early May"
    assert html =~ "60"
    assert html =~ "Great companion plant"
  end

  test "shows a back link to the seed library", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    assert html =~ ~p"/seeds"
  end

  test "returns 404 for unknown id", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/seeds/#{Ecto.UUID.generate()}")
    end
  end
end
```

- [ ] **Step 8.2: Run to verify tests fail**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: error — `BackyardGardenWeb.Seeds.ShowLive` does not exist.

- [ ] **Step 8.3: Create the ShowLive module**

Create `lib/backyard_garden_web/live/seeds/show_live.ex`:

```elixir
defmodule BackyardGardenWeb.Seeds.ShowLive do
  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed!(id)
    {:ok, assign(socket, :seed, seed)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.seed.name)}
  end
end
```

- [ ] **Step 8.4: Create the show template**

Create `lib/backyard_garden_web/live/seeds/show_live.html.heex`:

```heex
<div class="max-w-2xl space-y-6">
  <div>
    <a href={~p"/seeds"} class="text-sm text-green-700 hover:underline">← Back to Seed Library</a>
  </div>

  <div class="bg-white rounded-xl border border-stone-200 shadow-sm p-6 space-y-4">
    <div class="flex items-start justify-between gap-4">
      <h1 class="text-2xl font-bold text-stone-800"><%= @seed.name %></h1>
      <span class="shrink-0 rounded-full bg-green-100 text-green-800 text-xs font-medium px-2.5 py-1">
        <%= @seed.type %>
      </span>
    </div>

    <dl class="grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
      <div>
        <dt class="text-stone-500 font-medium">Brand</dt>
        <dd class="text-stone-800"><%= @seed.brand || "—" %></dd>
      </div>
      <div>
        <dt class="text-stone-500 font-medium">Cycle</dt>
        <dd class="text-stone-800"><%= @seed.cycle || "—" %></dd>
      </div>
      <div>
        <dt class="text-stone-500 font-medium">Planting method</dt>
        <dd class="text-stone-800"><%= @seed.planting_method || "—" %></dd>
      </div>
      <div>
        <dt class="text-stone-500 font-medium">Ideal planting time</dt>
        <dd class="text-stone-800"><%= @seed.ideal_planting_time || "—" %></dd>
      </div>
      <%= if @seed.maturity_days do %>
        <div>
          <dt class="text-stone-500 font-medium">Days to maturity</dt>
          <dd class="text-stone-800"><%= @seed.maturity_days %> days</dd>
        </div>
      <% end %>
      <%= if @seed.sun_requirement do %>
        <div>
          <dt class="text-stone-500 font-medium">Sun requirement</dt>
          <dd class="text-stone-800"><%= @seed.sun_requirement |> String.replace("_", " ") |> String.capitalize() %></dd>
        </div>
      <% end %>
    </dl>

    <%= if @seed.notes && @seed.notes != "" do %>
      <div class="border-t border-stone-100 pt-4">
        <dt class="text-stone-500 font-medium text-sm mb-1">Notes</dt>
        <dd class="text-stone-700 text-sm"><%= @seed.notes %></dd>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 8.5: Run all tests**

```bash
mix test
```

Expected:
```
.....................
All tests pass, 0 failures
```

- [ ] **Step 8.6: Verify in the browser**

```bash
mix phx.server
```

Visit `http://localhost:4000/seeds`, click on any seed name. You should see the detail page with all available fields and a back link. Stop with `Ctrl+C`.

- [ ] **Step 8.7: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/show_live.ex
git add lib/backyard_garden_web/live/seeds/show_live.html.heex
git add test/backyard_garden_web/live/seeds/show_live_test.exs
git commit -m "feat: seed detail LiveView"
```

---

## Phase 1 Complete

At this point you have:

- A running Phoenix app at `http://localhost:4000`
- 62 seeds imported from the CSV
- A mobile-responsive seed library with live search and filtering
- Seed detail pages
- A full test suite

**To run the app:**
```bash
mix phx.server
# Visit http://localhost:4000/seeds
```

**To run all tests:**
```bash
mix test
```

---

## Next: Phase 2 — Garden & Planting Tracking

Phase 2 plan covers:
- `garden_zones` migration and default zone data
- `plantings` migration (with `zone_id` FK)
- My Garden LiveView — list by status (planned / planted / harvested)
- Log Planting form — seed picker, zone recommendation, date, location, notes
- Status transitions (planned → planted → harvested)
- Planting Calendar — month view with ideal window overlays
- Import existing plantings from `Seed Planting 2026.csv` (Spinach and Swiss Chard)
- Seed edit form for `sun_requirement`

See `docs/superpowers/plans/` for the Phase 2 plan when you're ready.
