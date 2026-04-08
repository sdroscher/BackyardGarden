defmodule Mix.Tasks.Supplier.Scrape do
  @moduledoc """
  Fetches and upserts products from West Coast Seeds and Metchosin Farm
  into the supplier_products table. Safe to re-run — uses upsert.

  Usage:
      mix supplier.scrape                   # full catalog scrape
      mix supplier.scrape <product_url>     # import a single product by URL
  """

  use Mix.Task

  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.SupplierCatalog.Scrapers.{MetchosinFarm, WestCoastSeeds}

  @shortdoc "Scrape supplier catalogs into supplier_products"

  @suppliers %{
    "https://www.westcoastseeds.com" => {"West Coast Seeds", WestCoastSeeds},
    "https://metchosinfarm.ca" => {"Metchosin Farm", MetchosinFarm}
  }

  @impl Mix.Task
  def run([url]) do
    Mix.Task.run("app.start")
    import_single_product(url)
    Mix.shell().info("Done.")
  end

  def run(_args) do
    Mix.Task.run("app.start")
#    scrape("West Coast Seeds", &WestCoastSeeds.fetch_all_products/0)
    scrape("Metchosin Farm", &MetchosinFarm.fetch_all_products/0)
    Mix.shell().info("Done.")
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
