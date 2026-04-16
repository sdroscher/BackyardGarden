# Brother Nature Supplier Scraper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add brothernature.ca as a third supplier scraper, wired into the catalog context and mix task.

**Architecture:** New `BrotherNature` scraper module following the same Shopify `/products.json` + per-product HTML pattern as `WestCoastSeeds`. Three touch-points: the new scraper file, `SupplierCatalog` context (URL parsing + `fetch_and_store`), and the `supplier.scrape` mix task.

**Tech Stack:** Elixir, Req, Floki, Ecto upsert, Mix task

---

### Task 1: Write the BrotherNature scraper module

**Files:**
- Create: `lib/backyard_garden/supplier_catalog/scrapers/brother_nature.ex`

- [ ] **Step 1: Create the scraper module**

```elixir
defmodule BackyardGarden.SupplierCatalog.Scrapers.BrotherNature do
  @moduledoc """
  Fetches all products from the Brother Nature Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  Per-product HTML pages are scraped for "Seed Details" and "Instructions"
  sections (both use the `div.seed-details` CSS class).
  """

  @base_url "https://brothernature.ca"
  @supplier "brother_nature"
  # Gift Cards and blank types are not seed products
  @excluded_types ["Gift Cards", ""]

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  @doc "Fetches a single product by handle, including care HTML scraped from the product page."
  def fetch_product(handle) do
    case Req.get("#{@base_url}/products/#{handle}.json",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        attrs = to_attrs(body["product"])
        Map.put(attrs, :care_html, fetch_care_html(handle))

      {:ok, %{status: 429}} ->
        raise "Brother Nature rate limited (429) — try again later"

      {:ok, %{status: 404}} ->
        raise "Product not found on Brother Nature (404)"

      {:ok, %{status: status}} ->
        raise "Brother Nature returned status #{status}"

      {:error, reason} ->
        raise "Brother Nature connection error: #{inspect(reason)}"
    end
  end

  defp fetch_page(page, acc) do
    case Req.get("#{@base_url}/products.json?limit=250&page=#{page}",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        case body["products"] do
          [] ->
            acc

          products ->
            new_attrs = process_products(products)
            Process.sleep(3000)
            fetch_page(page + 1, acc ++ new_attrs)
        end

      {:ok, %{status: 429}} ->
        Mix.shell().error("Brother Nature rate limited (429), stopping scrape")
        acc

      {:ok, %{status: status}} ->
        Mix.shell().error("Brother Nature API returned status #{status}, stopping scrape")
        acc

      {:error, reason} ->
        Mix.shell().error("Brother Nature API error: #{inspect(reason)}, stopping scrape")
        acc
    end
  end

  defp process_products(products) do
    seed_products = Enum.reject(products, &excluded_product?/1)

    seed_products
    |> Task.async_stream(
      fn product ->
        attrs = to_attrs(product)
        Map.put(attrs, :care_html, fetch_care_html(attrs[:handle]))
      end,
      max_concurrency: 2,
      timeout: 20_000
    )
    |> Enum.map(fn {:ok, attrs} -> attrs end)
  end

  defp excluded_product?(product) do
    (product["product_type"] || "") in @excluded_types
  end

  # GETs the product HTML page and extracts all `div.seed-details` blocks
  # (used for both "Seed Details" and "Instructions" sections).
  # Returns nil if no sections found.
  defp fetch_care_html(handle) do
    case Req.get("#{@base_url}/products/#{handle}",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{body: html}} when is_binary(html) ->
        parse_care_html(html)

      _ ->
        nil
    end
  end

  defp parse_care_html(html) do
    {:ok, document} = Floki.parse_document(html)

    sections =
      document
      |> Floki.find("div.seed-details")
      |> Enum.map(&Floki.raw_html/1)

    if sections == [], do: nil, else: Enum.join(sections, "\n")
  end

  defp to_attrs(product) do
    %{
      supplier: @supplier,
      shopify_product_id: product["id"],
      handle: product["handle"],
      title: product["title"],
      product_type: product["product_type"],
      tags: normalize_tags(product["tags"]),
      description_html: product["body_html"],
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp normalize_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp normalize_tags(tags), do: tags

  defp user_agent_headers do
    [
      {"user-agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"},
      {"accept", "application/json"},
      {"accept-encoding", "gzip, deflate"},
      {"accept-language", "en-US,en;q=0.9"},
      {"sec-ch-ua",
       "\"Chromium\";v=\"146\", \"Not-A.Brand\";v=\"24\", \"Google Chrome\";v=\"146\""},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", "\"macOS\""},
      {"sec-fetch-dest", "document"},
      {"sec-fetch-mode", "navigate"},
      {"sec-fetch-site", "none"},
      {"sec-fetch-user", "?1"},
      {"upgrade-insecure-requests", "1"}
    ]
  end
end
```

- [ ] **Step 2: Run format and credo**

```bash
mix format lib/backyard_garden/supplier_catalog/scrapers/brother_nature.ex
mix credo lib/backyard_garden/supplier_catalog/scrapers/brother_nature.ex
```

Expected: no warnings, no credo violations.

- [ ] **Step 3: Commit**

```bash
git add lib/backyard_garden/supplier_catalog/scrapers/brother_nature.ex
git commit -m "feat: add BrotherNature scraper module"
```

---

### Task 2: Register Brother Nature in the SupplierCatalog context

**Files:**
- Modify: `lib/backyard_garden/supplier_catalog.ex`

Three changes in `supplier_catalog.ex`:

1. Add `brothernature.ca` branch in `parse_supplier_url/1`
2. Add `fetch_and_store("brother_nature", handle)` clause
3. Update the error message to include brothernature.ca

- [ ] **Step 1: Write a failing test**

In `test/backyard_garden/supplier_catalog_test.exs`, add inside the existing `describe "fetch_and_upsert_by_url/1"` block (or create the describe block if absent):

```elixir
describe "fetch_and_upsert_by_url/1" do
  test "returns error for unrecognised supplier URL" do
    assert {:error, msg} = SupplierCatalog.fetch_and_upsert_by_url("https://example.com/products/foo")
    assert msg =~ "brothernature.ca"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/backyard_garden/supplier_catalog_test.exs --only "returns error for unrecognised"
```

Expected: FAIL — message does not yet contain "brothernature.ca".

- [ ] **Step 3: Update `parse_supplier_url/1` and add `fetch_and_store` clause**

In `lib/backyard_garden/supplier_catalog.ex`, update `parse_supplier_url/1`:

```elixir
defp parse_supplier_url(url) do
  uri = URI.parse(url)
  host = uri.host || ""
  path = uri.path || ""

  cond do
    String.contains?(host, "westcoastseeds.com") ->
      extract_handle(path, "west_coast_seeds")

    String.contains?(host, "metchosinfarm.ca") ->
      extract_handle(path, "metchosin_farm")

    String.contains?(host, "brothernature.ca") ->
      extract_handle(path, "brother_nature")

    true ->
      {:error, "URL must be from westcoastseeds.com, metchosinfarm.ca, or brothernature.ca"}
  end
end
```

Add the new `fetch_and_store` clause after the existing `metchosin_farm` one:

```elixir
defp fetch_and_store("brother_nature", handle) do
  attrs = BackyardGarden.SupplierCatalog.Scrapers.BrotherNature.fetch_product(handle)

  case upsert_supplier_product(attrs) do
    {:ok, product} -> {:ok, product}
    {:error, _} -> {:error, "Failed to save supplier product"}
  end
rescue
  e -> {:error, Exception.message(e)}
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/backyard_garden/supplier_catalog_test.exs --only "returns error for unrecognised"
```

Expected: PASS.

- [ ] **Step 5: Run full test suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden/supplier_catalog.ex test/backyard_garden/supplier_catalog_test.exs
git commit -m "feat: register Brother Nature in SupplierCatalog context"
```

---

### Task 3: Add Brother Nature to the mix task

**Files:**
- Modify: `lib/mix/tasks/supplier.scrape.ex`

- [ ] **Step 1: Update the mix task**

In `lib/mix/tasks/supplier.scrape.ex`, update the `@moduledoc`, `@suppliers` map, and `run/1`:

```elixir
defmodule Mix.Tasks.Supplier.Scrape do
  @moduledoc """
  Fetches and upserts products from West Coast Seeds, Metchosin Farm, and Brother Nature
  into the supplier_products table. Safe to re-run — uses upsert.

  Usage:
      mix supplier.scrape                   # full catalog scrape
      mix supplier.scrape <product_url>     # import a single product by URL
  """

  use Mix.Task

  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.SupplierCatalog.Scrapers.{BrotherNature, MetchosinFarm, WestCoastSeeds}

  @shortdoc "Scrape supplier catalogs into supplier_products"

  @suppliers %{
    "https://www.westcoastseeds.com" => {"West Coast Seeds", WestCoastSeeds},
    "https://metchosinfarm.ca" => {"Metchosin Farm", MetchosinFarm},
    "https://brothernature.ca" => {"Brother Nature", BrotherNature}
  }

  @impl Mix.Task
  def run([url]) do
    configure_logging()
    Mix.Task.run("app.start")
    import_single_product(url)
    Mix.shell().info("Done.")
  end

  def run(_args) do
    configure_logging()
    Mix.Task.run("app.start")
    scrape("West Coast Seeds", &WestCoastSeeds.fetch_all_products/0)
    scrape("Metchosin Farm", &MetchosinFarm.fetch_all_products/0)
    scrape("Brother Nature", &BrotherNature.fetch_all_products/0)
    Mix.shell().info("Done.")
  end

  defp configure_logging do
    Logger.configure(level: :info)
    Logger.put_module_level(Ecto.SQL, :info)
  end

  defp import_single_product(url) do
    {base_url, {name, scraper}} =
      Enum.find(@suppliers, fn {base, _} -> String.starts_with?(url, base) end) ||
        Mix.raise("Unrecognised supplier URL: #{url}")

    handle = url |> String.replace_prefix(base_url <> "/products/", "") |> URI.decode()
    Mix.shell().info("Importing #{name} product: #{handle}...")

    try do
      attrs = scraper.fetch_product(handle)

      case SupplierCatalog.upsert_supplier_product(attrs) do
        {:ok, product} ->
          Mix.shell().info(~s|Imported "#{product.title}" (#{product.id})|)

        {:error, changeset} ->
          Mix.shell().error("Failed: #{inspect(changeset.errors)}")
      end
    rescue
      e in RuntimeError ->
        Mix.shell().error("Failed: #{e.message}")
    end
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

- [ ] **Step 2: Run format, credo, and tests**

```bash
mix format lib/mix/tasks/supplier.scrape.ex
mix credo lib/mix/tasks/supplier.scrape.ex
mix test
```

Expected: no warnings, no credo violations, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/mix/tasks/supplier.scrape.ex
git commit -m "feat: add Brother Nature to supplier.scrape mix task"
```

---

### Task 4: Smoke test

- [ ] **Step 1: Import a single product via URL to verify end-to-end**

```bash
mix supplier.scrape https://brothernature.ca/products/cosmo-mix-seashell
```

Expected output:
```
Importing Brother Nature product: cosmo-mix-seashell...
Imported "Cosmo Mix - Seashell" (<uuid>)
Done.
```

- [ ] **Step 2: Verify care HTML was saved**

```bash
iex -S mix
```

```elixir
alias BackyardGarden.{Repo, SupplierCatalog.SupplierProduct}
p = Repo.get_by!(SupplierProduct, supplier: "brother_nature", handle: "cosmo-mix-seashell")
IO.puts(p.care_html)
```

Expected: HTML containing "Seed Details" and "Instructions" content.
