defmodule Mix.Tasks.Supplier.Scrape do
  @moduledoc """
  Fetches and upserts products from West Coast Seeds, Metchosin Farm, and Brother Nature
  into the supplier_products table. Safe to re-run — uses upsert.

  Usage:
      mix supplier.scrape                          # scrape all suppliers
      mix supplier.scrape west_coast_seeds         # scrape one supplier
      mix supplier.scrape metchosin_farm
      mix supplier.scrape brother_nature
      mix supplier.scrape <product_url>            # import a single product by URL
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

  @supplier_keys %{
    "west_coast_seeds" => {"West Coast Seeds", &WestCoastSeeds.fetch_all_products/0},
    "metchosin_farm" => {"Metchosin Farm", &MetchosinFarm.fetch_all_products/0},
    "brother_nature" => {"Brother Nature", &BrotherNature.fetch_all_products/0}
  }

  @impl Mix.Task
  def run([arg]) do
    configure_logging()
    Mix.Task.run("app.start")

    if String.starts_with?(arg, "http") do
      import_single_product(arg)
    else
      case Map.fetch(@supplier_keys, arg) do
        {:ok, {name, fetch_fn}} ->
          scrape(name, fetch_fn)

        :error ->
          Mix.raise(
            "Unknown supplier #{inspect(arg)}. Valid keys: #{Map.keys(@supplier_keys) |> Enum.join(", ")}"
          )
      end
    end

    Mix.shell().info("Done.")
  end

  def run(_args) do
    configure_logging()
    Mix.Task.run("app.start")
    Enum.each(@supplier_keys, fn {_key, {name, fetch_fn}} -> scrape(name, fetch_fn) end)
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
    {upserted, skipped, errors} = fetch_fn.()
    Mix.shell().info("#{name}: #{upserted} upserted, #{skipped} skipped, #{errors} errors.")
  end
end
