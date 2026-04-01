# Supplier Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scrape West Coast Seeds and Metchosin Farm Shopify catalogs into a local `supplier_products` table, fuzzy-match existing seeds to supplier products, and display supplier care HTML on the seed detail page.

**Architecture:** Both suppliers expose public Shopify JSON APIs (`/products.json?limit=250&page=N`). Products are upserted into a `supplier_products` table keyed on `supplier + shopify_product_id`. Existing seeds are linked via a nullable FK. Three Mix tasks handle scraping, matching, and manual linking.

**Tech Stack:** Elixir + Phoenix LiveView + Ecto (SQLite3) + `Req` (HTTP client, new dep)

---

## File Map

**New files:**
- `priv/repo/migrations/TIMESTAMP_create_supplier_products.exs`
- `priv/repo/migrations/TIMESTAMP_add_supplier_product_id_to_seeds.exs`
- `lib/backyard_garden/supplier_catalog/supplier_product.ex` — Ecto schema
- `lib/backyard_garden/supplier_catalog.ex` — context (upsert, list, fuzzy match)
- `lib/backyard_garden/supplier_catalog/scrapers/west_coast_seeds.ex`
- `lib/backyard_garden/supplier_catalog/scrapers/metchosin_farm.ex`
- `lib/mix/tasks/supplier.scrape.ex`
- `lib/mix/tasks/supplier.match.ex`
- `lib/mix/tasks/supplier.link.ex`
- `test/backyard_garden/supplier_catalog_test.exs`

**Modified files:**
- `mix.exs` — add `req` dependency
- `lib/backyard_garden/seeds/seed.ex` — add `belongs_to :supplier_product`, cast `supplier_product_id`
- `lib/backyard_garden/seeds/seeds.ex` — add `get_seed_with_supplier!/1`
- `lib/backyard_garden_web/live/seeds/show_live.ex` — call `get_seed_with_supplier!/1`
- `lib/backyard_garden_web/live/seeds/show_live.html.heex` — add supplier section
- `test/backyard_garden_web/live/seeds/show_live_test.exs` — add supplier section tests

---

## Task 1: Add `req` HTTP client dependency

**Files:**
- Modify: `mix.exs`

`req` is not yet in the project. It is needed by the scraper modules.

- [ ] **Step 1: Add the dependency**

In `mix.exs`, add to the `deps/0` list (after `{:bandit, ...}`):

```elixir
{:req, "~> 0.5"},
```

- [ ] **Step 2: Fetch the dependency**

```bash
mix deps.get
```

Expected: `req` and any transitive deps are fetched, no errors.

- [ ] **Step 3: Verify it compiles**

```bash
mix compile
```

Expected: Compiled with no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add mix.exs mix.lock
git commit -m "chore: add req HTTP client dependency"
```

---

## Task 2: Create `supplier_products` migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_supplier_products.exs`

- [ ] **Step 1: Generate the migration file**

```bash
mix ecto.gen.migration create_supplier_products
```

Expected: Creates `priv/repo/migrations/TIMESTAMP_create_supplier_products.exs`.

- [ ] **Step 2: Fill in the migration**

Open the generated file and replace the `change/0` body:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreateSupplierProducts do
  use Ecto.Migration

  def change do
    create table(:supplier_products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :supplier, :string, null: false
      add :shopify_product_id, :integer, null: false
      add :handle, :string, null: false
      add :title, :string, null: false
      add :product_type, :string
      add :tags, :string
      add :description_html, :text
      add :url, :string, null: false
      add :scraped_at, :utc_datetime

      timestamps()
    end

    create unique_index(:supplier_products, [:supplier, :shopify_product_id])
    create index(:supplier_products, [:supplier])
    create index(:supplier_products, [:title])
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

Expected: `create table supplier_products`, `create index supplier_products_supplier_shopify_product_id_index`, done.

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat: add supplier_products migration"
```

---

## Task 3: `SupplierProduct` schema and context

**Files:**
- Create: `lib/backyard_garden/supplier_catalog/supplier_product.ex`
- Create: `lib/backyard_garden/supplier_catalog.ex`
- Create: `test/backyard_garden/supplier_catalog_test.exs`

- [ ] **Step 1: Write the failing tests**

Create `test/backyard_garden/supplier_catalog_test.exs`:

```elixir
defmodule BackyardGarden.SupplierCatalogTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.Seeds

  defp product_fixture(attrs \\ %{}) do
    defaults = %{
      supplier: "metchosin_farm",
      shopify_product_id: 12_345,
      handle: "mullein",
      title: "Mullein",
      url: "https://metchosinfarm.ca/products/mullein",
      scraped_at: ~U[2026-04-01 00:00:00Z]
    }

    {:ok, product} = SupplierCatalog.upsert_supplier_product(Map.merge(defaults, attrs))
    product
  end

  describe "upsert_supplier_product/1" do
    test "inserts a new supplier product" do
      attrs = %{
        supplier: "west_coast_seeds",
        shopify_product_id: 99_999,
        handle: "desert-organic",
        title: "Desert Organic",
        url: "https://www.westcoastseeds.com/products/desert-organic",
        scraped_at: ~U[2026-04-01 00:00:00Z]
      }

      assert {:ok, product} = SupplierCatalog.upsert_supplier_product(attrs)
      assert product.title == "Desert Organic"
      assert product.supplier == "west_coast_seeds"
    end

    test "updates an existing product on duplicate supplier + shopify_product_id" do
      attrs = %{
        supplier: "metchosin_farm",
        shopify_product_id: 12_345,
        handle: "mullein",
        title: "Mullein",
        url: "https://metchosinfarm.ca/products/mullein",
        scraped_at: ~U[2026-04-01 00:00:00Z]
      }

      {:ok, _} = SupplierCatalog.upsert_supplier_product(attrs)

      {:ok, updated} =
        SupplierCatalog.upsert_supplier_product(Map.put(attrs, :title, "Mullein (Updated)"))

      assert updated.title == "Mullein (Updated)"
      assert length(BackyardGarden.Repo.all(BackyardGarden.SupplierCatalog.SupplierProduct)) == 1
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, changeset} = SupplierCatalog.upsert_supplier_product(%{})
      assert %{supplier: _} = errors_on(changeset)
    end
  end

  describe "list_supplier_products/1" do
    test "returns all products ordered by title when no filters" do
      product_fixture(%{title: "Zucchini", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      titles = SupplierCatalog.list_supplier_products() |> Enum.map(& &1.title)
      assert titles == ["Basil", "Zucchini"]
    end

    test "filters by supplier" do
      product_fixture(%{supplier: "metchosin_farm", shopify_product_id: 1, title: "Mullein"})

      product_fixture(%{
        supplier: "west_coast_seeds",
        shopify_product_id: 2,
        title: "Desert Squash"
      })

      products = SupplierCatalog.list_supplier_products(%{supplier: "metchosin_farm"})
      assert length(products) == 1
      assert hd(products).title == "Mullein"
    end

    test "searches by title (case-insensitive)" do
      product_fixture(%{title: "Purple Mullein", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      products = SupplierCatalog.list_supplier_products(%{search: "mullein"})
      assert length(products) == 1
      assert hd(products).title == "Purple Mullein"
    end
  end

  describe "find_match_for_seed/1" do
    test "returns the best-matching supplier product and its score" do
      product_fixture(%{title: "Bush Bean Mix", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      {:ok, seed} = Seeds.create_seed(%{name: "Bush Beans - Mix"})
      {product, score} = SupplierCatalog.find_match_for_seed(seed)
      assert product.title == "Bush Bean Mix"
      assert score > 0.75
    end

    test "returns {nil, 0.0} when the supplier_products table is empty" do
      {:ok, seed} = Seeds.create_seed(%{name: "Tomato"})
      assert {nil, 0.0} = SupplierCatalog.find_match_for_seed(seed)
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
mix test test/backyard_garden/supplier_catalog_test.exs
```

Expected: compile error — `BackyardGarden.SupplierCatalog` does not exist.

- [ ] **Step 3: Create the `SupplierProduct` schema**

Create `lib/backyard_garden/supplier_catalog/supplier_product.ex`:

```elixir
defmodule BackyardGarden.SupplierCatalog.SupplierProduct do
  @moduledoc """
  Schema for a product entry scraped from a seed supplier's Shopify catalog.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "supplier_products" do
    field :supplier, :string
    field :shopify_product_id, :integer
    field :handle, :string
    field :title, :string
    field :product_type, :string
    field :tags, :string
    field :description_html, :string
    field :url, :string
    field :scraped_at, :utc_datetime

    timestamps()
  end

  def changeset(supplier_product, attrs) do
    supplier_product
    |> cast(attrs, [
      :supplier,
      :shopify_product_id,
      :handle,
      :title,
      :product_type,
      :tags,
      :description_html,
      :url,
      :scraped_at
    ])
    |> validate_required([:supplier, :shopify_product_id, :handle, :title, :url])
    |> unique_constraint([:supplier, :shopify_product_id])
  end
end
```

- [ ] **Step 4: Create the `SupplierCatalog` context**

Create `lib/backyard_garden/supplier_catalog.ex`:

```elixir
defmodule BackyardGarden.SupplierCatalog do
  @moduledoc """
  Context for managing supplier product catalog data scraped from Shopify stores.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.SupplierCatalog.SupplierProduct

  @doc "Returns all supplier products matching the given filters, ordered by title."
  def list_supplier_products(filters \\ %{}) do
    SupplierProduct
    |> filter_by_supplier(filters[:supplier])
    |> filter_by_search(filters[:search])
    |> order_by([p], p.title)
    |> Repo.all()
  end

  @doc """
  Upserts a supplier product by supplier + shopify_product_id.
  Safe to call repeatedly — re-running updates all fields except id and inserted_at.
  """
  def upsert_supplier_product(attrs) do
    %SupplierProduct{}
    |> SupplierProduct.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:supplier, :shopify_product_id]
    )
  end

  @doc """
  Returns {supplier_product, score} for the best fuzzy name match against the given seed,
  where score is 0.0–1.0 (Jaro distance). Returns {nil, 0.0} if no products exist.
  """
  def find_match_for_seed(seed) do
    Repo.all(SupplierProduct)
    |> Enum.map(fn product ->
      score =
        String.jaro_distance(String.downcase(seed.name), String.downcase(product.title))

      {product, score}
    end)
    |> Enum.max_by(fn {_product, score} -> score end, fn -> {nil, 0.0} end)
  end

  defp filter_by_supplier(query, nil), do: query
  defp filter_by_supplier(query, ""), do: query
  defp filter_by_supplier(query, supplier), do: where(query, [p], p.supplier == ^supplier)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    term = "%#{String.downcase(search)}%"
    where(query, [p], like(fragment("lower(?)", p.title), ^term))
  end
end
```

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden/supplier_catalog_test.exs
```

Expected: All tests pass.

- [ ] **Step 6: Run full test suite and linter**

```bash
mix test && mix credo
```

Expected: All tests pass, no Credo warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/supplier_catalog.ex \
        lib/backyard_garden/supplier_catalog/ \
        test/backyard_garden/supplier_catalog_test.exs
git commit -m "feat: add SupplierCatalog context and SupplierProduct schema"
```

---

## Task 4: Add `supplier_product_id` FK to seeds

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_supplier_product_id_to_seeds.exs`
- Modify: `lib/backyard_garden/seeds/seed.ex`
- Modify: `lib/backyard_garden/seeds/seeds.ex`

- [ ] **Step 1: Generate the migration file**

```bash
mix ecto.gen.migration add_supplier_product_id_to_seeds
```

- [ ] **Step 2: Fill in the migration**

```elixir
defmodule BackyardGarden.Repo.Migrations.AddSupplierProductIdToSeeds do
  use Ecto.Migration

  def change do
    alter table(:seeds) do
      add :supplier_product_id,
          references(:supplier_products, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

Expected: `alter table seeds`, done.

- [ ] **Step 4: Update the `Seed` schema**

In `lib/backyard_garden/seeds/seed.ex`, add a `belongs_to` and include `supplier_product_id` in the changeset cast list:

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

    belongs_to :supplier_product, BackyardGarden.SupplierCatalog.SupplierProduct,
      type: :binary_id

    timestamps()
  end

  def changeset(seed, attrs) do
    seed
    |> cast(attrs, [
      :name,
      :brand,
      :type,
      :cycle,
      :planting_method,
      :ideal_planting_time,
      :maturity_days,
      :sun_requirement,
      :source_url,
      :notes,
      :supplier_product_id
    ])
    |> validate_required([:name])
  end
end
```

- [ ] **Step 5: Add `get_seed_with_supplier!/1` to the Seeds context**

In `lib/backyard_garden/seeds/seeds.ex`, add after `get_seed!/1`:

```elixir
@doc "Returns a single seed by id with supplier_product preloaded. Raises if not found."
def get_seed_with_supplier!(id) do
  get_seed!(id) |> Repo.preload(:supplier_product)
end
```

- [ ] **Step 6: Run the full test suite**

```bash
mix test
```

Expected: All existing tests still pass (no behaviour changed yet — ShowLive still calls `get_seed!/1`).

- [ ] **Step 7: Commit**

```bash
git add priv/repo/migrations/ \
        lib/backyard_garden/seeds/seed.ex \
        lib/backyard_garden/seeds/seeds.ex
git commit -m "feat: add supplier_product_id FK to seeds, update schema and context"
```

---

## Task 5: Scraper modules

**Files:**
- Create: `lib/backyard_garden/supplier_catalog/scrapers/west_coast_seeds.ex`
- Create: `lib/backyard_garden/supplier_catalog/scrapers/metchosin_farm.ex`

These modules make real HTTP calls so they are tested end-to-end via `mix supplier.scrape` in Task 6. No unit tests here — YAGNI.

- [ ] **Step 1: Create the West Coast Seeds scraper**

Create `lib/backyard_garden/supplier_catalog/scrapers/west_coast_seeds.ex`:

```elixir
defmodule BackyardGarden.SupplierCatalog.Scrapers.WestCoastSeeds do
  @moduledoc """
  Fetches all products from the West Coast Seeds Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  @base_url "https://www.westcoastseeds.com"
  @supplier "west_coast_seeds"

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  defp fetch_page(page, acc) do
    %{body: body} = Req.get!("#{@base_url}/products.json?limit=250&page=#{page}")

    case body["products"] do
      [] -> acc
      products -> fetch_page(page + 1, acc ++ Enum.map(products, &to_attrs/1))
    end
  end

  defp to_attrs(product) do
    %{
      supplier: @supplier,
      shopify_product_id: product["id"],
      handle: product["handle"],
      title: product["title"],
      product_type: product["product_type"],
      tags: product["tags"],
      description_html: product["body_html"],
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
```

- [ ] **Step 2: Create the Metchosin Farm scraper**

Create `lib/backyard_garden/supplier_catalog/scrapers/metchosin_farm.ex`:

```elixir
defmodule BackyardGarden.SupplierCatalog.Scrapers.MetchosinFarm do
  @moduledoc """
  Fetches all products from the Metchosin Farm Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  @base_url "https://metchosinfarm.ca"
  @supplier "metchosin_farm"

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  defp fetch_page(page, acc) do
    %{body: body} = Req.get!("#{@base_url}/products.json?limit=250&page=#{page}")

    case body["products"] do
      [] -> acc
      products -> fetch_page(page + 1, acc ++ Enum.map(products, &to_attrs/1))
    end
  end

  defp to_attrs(product) do
    %{
      supplier: @supplier,
      shopify_product_id: product["id"],
      handle: product["handle"],
      title: product["title"],
      product_type: product["product_type"],
      tags: product["tags"],
      description_html: product["body_html"],
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
```

- [ ] **Step 3: Verify compilation**

```bash
mix compile
```

Expected: No errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/backyard_garden/supplier_catalog/scrapers/
git commit -m "feat: add West Coast Seeds and Metchosin Farm scraper modules"
```

---

## Task 6: `mix supplier.scrape` task

**Files:**
- Create: `lib/mix/tasks/supplier.scrape.ex`

- [ ] **Step 1: Create the task**

Create `lib/mix/tasks/supplier.scrape.ex`:

```elixir
defmodule Mix.Tasks.Supplier.Scrape do
  @moduledoc """
  Fetches and upserts all products from West Coast Seeds and Metchosin Farm
  into the supplier_products table. Safe to re-run — uses upsert.

  Usage:
      mix supplier.scrape
  """

  use Mix.Task

  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.SupplierCatalog.Scrapers.{MetchosinFarm, WestCoastSeeds}

  @shortdoc "Scrape supplier catalogs into supplier_products"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    scrape("West Coast Seeds", &WestCoastSeeds.fetch_all_products/0)
    scrape("Metchosin Farm", &MetchosinFarm.fetch_all_products/0)
    Mix.shell().info("Done.")
  end

  defp scrape(name, fetch_fn) do
    Mix.shell().info("Scraping #{name}...")
    products = fetch_fn.()

    count =
      Enum.reduce(products, 0, fn attrs, acc ->
        case SupplierCatalog.upsert_supplier_product(attrs) do
          {:ok, _} ->
            acc + 1

          {:error, changeset} ->
            Mix.shell().error("Failed: #{attrs[:title]} — #{inspect(changeset.errors)}")
            acc
        end
      end)

    Mix.shell().info("#{name}: #{count} products upserted.")
  end
end
```

- [ ] **Step 2: Run the task to verify it works against the live APIs**

```bash
mix supplier.scrape
```

Expected output (numbers will vary):
```
Scraping West Coast Seeds...
West Coast Seeds: 312 products upserted.
Scraping Metchosin Farm...
Metchosin Farm: 89 products upserted.
Done.
```

If any products fail, the error message will show the reason.

- [ ] **Step 3: Verify products are in the database**

```bash
iex -S mix
```

Then in iex:
```elixir
BackyardGarden.SupplierCatalog.list_supplier_products() |> length()
# Should match the total from the scrape output
BackyardGarden.SupplierCatalog.list_supplier_products(%{supplier: "metchosin_farm"}) |> hd() |> Map.get(:title)
# Should return a Metchosin product title
```

- [ ] **Step 4: Run linter**

```bash
mix credo
```

Expected: No warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/supplier.scrape.ex
git commit -m "feat: add mix supplier.scrape task"
```

---

## Task 7: `mix supplier.match` task

**Files:**
- Create: `lib/mix/tasks/supplier.match.ex`

This task reads all seeds, fuzzy-matches them to supplier products, auto-links high-confidence matches, and prints borderline matches for manual review.

- [ ] **Step 1: Create the task**

Create `lib/mix/tasks/supplier.match.ex`:

```elixir
defmodule Mix.Tasks.Supplier.Match do
  @moduledoc """
  Fuzzy-matches seeds to supplier products by name similarity (Jaro distance).
  Auto-links seeds with score >= 0.90. Prints a review list for 0.75–0.89.
  Seeds with score < 0.75 are left unlinked.

  Run mix supplier.scrape first to populate supplier_products.

  Usage:
      mix supplier.match
  """

  use Mix.Task

  import Ecto.Query
  alias BackyardGarden.{Repo, Seeds, SupplierCatalog}
  alias BackyardGarden.Seeds.Seed

  @shortdoc "Match seeds to supplier products by name similarity"

  @auto_threshold 0.90
  @review_threshold 0.75

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    seeds = Seeds.list_seeds()

    {auto_count, review, unmatched} =
      Enum.reduce(seeds, {0, [], []}, fn seed, {auto_count, review_acc, unmatched_acc} ->
        case SupplierCatalog.find_match_for_seed(seed) do
          {nil, _} ->
            {auto_count, review_acc, [seed.name | unmatched_acc]}

          {product, score} when score >= @auto_threshold ->
            Repo.update_all(from(s in Seed, where: s.id == ^seed.id),
              set: [supplier_product_id: product.id]
            )

            {auto_count + 1, review_acc, unmatched_acc}

          {product, score} when score >= @review_threshold ->
            {auto_count, [{seed, product, score} | review_acc], unmatched_acc}

          {_, _} ->
            {auto_count, review_acc, [seed.name | unmatched_acc]}
        end
      end)

    Mix.shell().info("Auto-linked #{auto_count} seeds.\n")
    print_review_list(review)
    print_unmatched(unmatched)
  end

  defp print_review_list([]), do: :ok

  defp print_review_list(review) do
    Mix.shell().info(
      "Review needed (confirm with: mix supplier.link <seed_id> <supplier_product_id>):"
    )

    Enum.each(review, fn {seed, product, score} ->
      score_str = :erlang.float_to_binary(score, decimals: 2)
      supplier_label = product.supplier |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
      Mix.shell().info(~s|  "#{seed.name}"  →  "#{product.title}" (#{supplier_label}, #{score_str})|)
      Mix.shell().info(~s|    seed_id=#{seed.id}  product_id=#{product.id}|)
    end)

    Mix.shell().info("")
  end

  defp print_unmatched([]), do: :ok

  defp print_unmatched(unmatched) do
    Mix.shell().info("Unmatched seeds (#{length(unmatched)}): #{Enum.join(unmatched, ", ")}")
  end
end
```

- [ ] **Step 2: Run the task**

```bash
mix supplier.match
```

Expected: Output shows auto-linked count, any borderline matches (with seed_id and product_id for use with `mix supplier.link`), and any unmatched seed names. No errors.

- [ ] **Step 3: Spot-check an auto-linked seed in iex**

```bash
iex -S mix
```

```elixir
seed = BackyardGarden.Seeds.list_seeds() |> Enum.find(&(&1.name == "Borage"))
seed.supplier_product_id
# Should be a UUID string (not nil) if Borage was auto-linked
```

- [ ] **Step 4: Run linter**

```bash
mix credo
```

Expected: No warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/supplier.match.ex
git commit -m "feat: add mix supplier.match task"
```

---

## Task 8: `mix supplier.link` task

**Files:**
- Create: `lib/mix/tasks/supplier.link.ex`

- [ ] **Step 1: Create the task**

Create `lib/mix/tasks/supplier.link.ex`:

```elixir
defmodule Mix.Tasks.Supplier.Link do
  @moduledoc """
  Manually links a seed to a supplier product.
  Use this to confirm borderline matches printed by mix supplier.match.

  Usage:
      mix supplier.link <seed_id> <supplier_product_id>
  """

  use Mix.Task

  import Ecto.Query
  alias BackyardGarden.{Repo, Seeds}
  alias BackyardGarden.Seeds.Seed

  @shortdoc "Link a seed to a supplier product by ID"

  @impl Mix.Task
  def run([seed_id, supplier_product_id]) do
    Mix.Task.run("app.start")
    seed = Seeds.get_seed!(seed_id)
    Repo.update_all(from(s in Seed, where: s.id == ^seed.id), set: [supplier_product_id: supplier_product_id])
    Mix.shell().info(~s|Linked "#{seed.name}" → supplier_product #{supplier_product_id}|)
  end

  def run(_) do
    Mix.raise("Usage: mix supplier.link <seed_id> <supplier_product_id>")
  end
end
```

- [ ] **Step 2: Test manually using an unlinked seed and a real product ID**

Pick a `seed_id` and `supplier_product_id` from the `mix supplier.match` review output and run:

```bash
mix supplier.link <seed_id> <supplier_product_id>
```

Expected: `Linked "Seed Name" → supplier_product <uuid>`

Verify in iex:
```elixir
BackyardGarden.Seeds.get_seed!("<seed_id>").supplier_product_id
# Should equal the supplier_product_id you passed
```

- [ ] **Step 3: Test the error path**

```bash
mix supplier.link
```

Expected: `** (Mix.Error) Usage: mix supplier.link <seed_id> <supplier_product_id>`

- [ ] **Step 4: Run linter**

```bash
mix credo
```

Expected: No warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/supplier.link.ex
git commit -m "feat: add mix supplier.link task"
```

---

## Task 9: Seed detail page supplier section

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/show_live.ex`
- Modify: `lib/backyard_garden_web/live/seeds/show_live.html.heex`
- Modify: `test/backyard_garden_web/live/seeds/show_live_test.exs`

- [ ] **Step 1: Write the failing tests**

In `test/backyard_garden_web/live/seeds/show_live_test.exs`, add after the existing tests. You'll need to alias `SupplierCatalog` at the top — add to the module body:

```elixir
alias BackyardGarden.SupplierCatalog
```

Then add these two tests:

```elixir
test "renders supplier section when seed is linked to a supplier product", %{conn: conn} do
  {:ok, product} =
    SupplierCatalog.upsert_supplier_product(%{
      supplier: "metchosin_farm",
      shopify_product_id: 11_111,
      handle: "purple-basil",
      title: "Purple Basil",
      description_html: "<p>Great companion plant for tomatoes.</p>",
      url: "https://metchosinfarm.ca/products/purple-basil",
      scraped_at: ~U[2026-04-01 00:00:00Z]
    })

  {:ok, seed} =
    Seeds.create_seed(%{name: "Purple Basil", type: "Herb", supplier_product_id: product.id})

  {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")

  assert html =~ "From the Supplier"
  assert html =~ "Great companion plant for tomatoes."
  assert html =~ "metchosinfarm.ca/products/purple-basil"
end

test "does not render supplier section when seed has no supplier product", %{
  conn: conn,
  seed: seed
} do
  {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
  refute html =~ "From the Supplier"
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: The two new tests fail — `"From the Supplier"` is never rendered, and the existing test for `get_seed!` is still passing.

- [ ] **Step 3: Update `ShowLive` to preload the supplier product**

In `lib/backyard_garden_web/live/seeds/show_live.ex`, change the `mount/3` call from `Seeds.get_seed!` to `Seeds.get_seed_with_supplier!`:

```elixir
defmodule BackyardGardenWeb.Seeds.ShowLive do
  @moduledoc """
  LiveView for displaying a single seed's details.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed_with_supplier!(id)
    {:ok, assign(socket, :seed, seed)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.seed.name)}
  end
end
```

- [ ] **Step 4: Add the supplier section to the template**

In `lib/backyard_garden_web/live/seeds/show_live.html.heex`, add after the closing `</div>` of the existing card (after line 56):

```heex
<%= if @seed.supplier_product do %>
  <div class="bg-white rounded-xl border border-stone-200 shadow-sm p-6 space-y-3">
    <div class="flex items-start justify-between gap-4">
      <h2 class="text-lg font-semibold text-stone-800">From the Supplier</h2>
      <a
        href={@seed.supplier_product.url}
        target="_blank"
        rel="noopener noreferrer"
        class="shrink-0 text-sm text-green-700 hover:underline"
      >
        View on supplier site →
      </a>
    </div>
    <div class="text-sm text-stone-700 space-y-2">
      {raw(@seed.supplier_product.description_html)}
    </div>
  </div>
<% end %>
```

Note: `raw/1` is from `Phoenix.HTML`, imported globally via `BackyardGardenWeb.html_helpers/0`. It renders HTML as-is without escaping. The source is trusted (our own scrape of known Shopify stores).

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: All tests pass.

- [ ] **Step 6: Run the full suite and linter**

```bash
mix test && mix credo
```

Expected: All tests pass, no Credo warnings.

- [ ] **Step 7: Smoke-test in the browser**

```bash
mix phx.server
```

Visit a seed that was linked by `mix supplier.match` (check `iex -S mix` for one with a non-nil `supplier_product_id`). The "From the Supplier" card should appear below the seed details with the supplier's HTML content and a "View on supplier site →" link.

Visit a seed without a link — the section should not appear.

- [ ] **Step 8: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/show_live.ex \
        lib/backyard_garden_web/live/seeds/show_live.html.heex \
        test/backyard_garden_web/live/seeds/show_live_test.exs
git commit -m "feat: render supplier product section on seed detail page"
```

---

## Final verification

- [ ] Run `mix precommit` to confirm everything passes end-to-end:

```bash
mix precommit
```

Expected: Compiles with no warnings, format clean, deps clean, all tests pass.
