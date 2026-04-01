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
