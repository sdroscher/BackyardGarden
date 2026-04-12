defmodule BackyardGarden.SupplierCatalog do
  @moduledoc """
  Context for managing supplier product catalog data scraped from Shopify stores.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.SupplierCatalog.SupplierProduct

  @doc "Returns a supplier product by id. Raises Ecto.NoResultsError if not found."
  def get_supplier_product!(id), do: Repo.get!(SupplierProduct, id)

  @doc "Returns all supplier products matching the given filters, ordered by title."
  def list_supplier_products(filters \\ %{}) do
    SupplierProduct
    |> filter_by_supplier(filters[:suppliers] || filters[:supplier])
    |> filter_by_search(filters[:search])
    |> order_by([p], p.title)
    |> Repo.all()
  end

  @doc """
  Upserts a supplier product by supplier + shopify_product_id.
  Safe to call repeatedly — re-running updates all fields except id and inserted_at.
  """
  def upsert_supplier_product(attrs) do
    {care_html, product_attrs} = Map.pop(attrs, :care_html)

    result =
      %SupplierProduct{}
      |> SupplierProduct.changeset(product_attrs)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :care_html]},
        conflict_target: [:supplier, :shopify_product_id]
      )

    if care_html && match?({:ok, _}, result) do
      update_care_html(product_attrs[:supplier], product_attrs[:handle], care_html)
    end

    result
  end

  @doc """
  Updates the care_html for the product identified by supplier + handle.
  Used by the single-product scrape to set care guide content without going through upsert.
  """
  def update_care_html(supplier, handle, care_html) do
    from(p in SupplierProduct, where: p.supplier == ^supplier and p.handle == ^handle)
    |> Repo.update_all(set: [care_html: care_html])
  end

  @doc """
  Returns {supplier_product, score} for the best fuzzy name match against the given seed,
  where score is 0.0–1.0 (Jaro distance). Returns {nil, 0.0} if no products exist.

  Options:
    - `:supplier` — restrict candidates to a specific supplier key (e.g. "west_coast_seeds")
  """
  def find_match_for_seed(seed, opts \\ []) do
    SupplierProduct
    |> filter_by_supplier(opts[:supplier])
    |> Repo.all()
    |> Enum.map(fn product ->
      {product, match_score(seed.name, product.title)}
    end)
    |> Enum.max_by(fn {_product, score} -> score end, fn -> {nil, 0.0} end)
  end

  # Try matching on the full seed name and on the part after " - " (stripped of user-added
  # category prefixes like "Zucchini - "), taking the higher score.
  defp match_score(seed_name, product_title) do
    product_lower = String.downcase(product_title)
    full_score = String.jaro_distance(String.downcase(seed_name), product_lower)

    case String.split(seed_name, " - ", parts: 2) do
      [_prefix, variety] ->
        max(full_score, String.jaro_distance(String.downcase(variety), product_lower))

      _ ->
        full_score
    end
  end

  @doc """
  Fetches and upserts a supplier product by URL.

  Parses the URL to identify the supplier and product handle, checks for an
  existing record in the database (returning it immediately if found), otherwise
  calls the appropriate scraper to fetch and upsert.

  Returns `{:ok, supplier_product}` or `{:error, reason}`.
  """
  def fetch_and_upsert_by_url(url) do
    case parse_supplier_url(url) do
      {:ok, supplier, handle} ->
        case Repo.get_by(SupplierProduct, supplier: supplier, handle: handle) do
          %SupplierProduct{} = existing ->
            {:ok, existing}

          nil ->
            fetch_and_store(supplier, handle)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_supplier_url(url) do
    uri = URI.parse(url)
    host = uri.host || ""
    path = uri.path || ""

    cond do
      String.contains?(host, "westcoastseeds.com") ->
        extract_handle(path, "west_coast_seeds")

      String.contains?(host, "metchosinfarm.ca") ->
        extract_handle(path, "metchosin_farm")

      true ->
        {:error, "URL must be from westcoastseeds.com or metchosinfarm.ca"}
    end
  end

  defp extract_handle(path, supplier) do
    case Regex.run(~r|/products/([^/?#]+)|, path) do
      [_, handle] -> {:ok, supplier, handle}
      _ -> {:error, "Could not extract product handle from URL"}
    end
  end

  defp fetch_and_store("west_coast_seeds", handle) do
    attrs = BackyardGarden.SupplierCatalog.Scrapers.WestCoastSeeds.fetch_product(handle)

    case upsert_supplier_product(attrs) do
      {:ok, product} -> {:ok, product}
      {:error, _} -> {:error, "Failed to save supplier product"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp fetch_and_store("metchosin_farm", handle) do
    attrs = BackyardGarden.SupplierCatalog.Scrapers.MetchosinFarm.fetch_product(handle)

    case upsert_supplier_product(attrs) do
      {:ok, product} -> {:ok, product}
      {:error, _} -> {:error, "Failed to save supplier product"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp filter_by_supplier(query, nil), do: query
  defp filter_by_supplier(query, ""), do: query

  defp filter_by_supplier(query, suppliers) when is_list(suppliers),
    do: where(query, [p], p.supplier in ^suppliers)

  defp filter_by_supplier(query, supplier), do: where(query, [p], p.supplier == ^supplier)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    escaped = search |> String.replace("%", "\\%") |> String.replace("_", "\\_")
    term = "%#{String.downcase(escaped)}%"
    where(query, [p], like(fragment("lower(?)", p.title), ^term))
  end
end
