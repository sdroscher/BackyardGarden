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
