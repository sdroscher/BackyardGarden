defmodule Mix.Tasks.Supplier.Link do
  @moduledoc """
  Manually links a seed to a supplier product.
  Use this to confirm borderline matches printed by mix supplier.match.

  The product can be identified by its UUID, its Shopify handle, or a full product URL
  (the handle is the slug after /products/ in the URL).

  Usage:
      mix supplier.link <seed_id> <product_id|handle|url>

  Examples:
      mix supplier.link <seed_id> f3a2...            # UUID
      mix supplier.link <seed_id> noche-zucchini     # handle
      mix supplier.link <seed_id> https://metchosinfarm.ca/products/noche-zucchini
  """

  use Mix.Task

  import Ecto.Query
  alias BackyardGarden.{Repo, Seeds}
  alias BackyardGarden.Seeds.Seed
  alias BackyardGarden.SupplierCatalog.SupplierProduct

  @shortdoc "Link a seed to a supplier product by ID, handle, or URL"

  @uuid_pattern ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  @impl Mix.Task
  def run([seed_id, product_ref]) do
    Logger.configure(level: :info)
    Mix.Task.run("app.start")
    seed = Seeds.get_seed!(seed_id)
    product = resolve_product!(product_ref)

    Repo.update_all(from(s in Seed, where: s.id == ^seed.id),
      set: [supplier_product_id: product.id]
    )

    Mix.shell().info(~s|Linked "#{seed.name}" → "#{product.title}" (#{product.id})|)
  end

  def run(_) do
    Mix.raise("Usage: mix supplier.link <seed_id> <product_id|handle|url>")
  end

  # Accept a UUID, a full product URL, or a bare handle.
  defp resolve_product!(ref) do
    handle =
      cond do
        Regex.match?(@uuid_pattern, ref) -> nil
        String.contains?(ref, "/products/") -> ref |> String.split("/products/") |> List.last()
        true -> ref
      end

    product =
      if handle do
        Repo.get_by(SupplierProduct, handle: handle)
      else
        Repo.get(SupplierProduct, ref)
      end

    product || Mix.raise("No supplier product found for: #{ref}")
  end
end
