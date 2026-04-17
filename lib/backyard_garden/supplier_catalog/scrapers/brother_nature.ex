defmodule BackyardGarden.SupplierCatalog.Scrapers.BrotherNature do
  @moduledoc """
  Fetches all products from the Brother Nature Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  Per-product HTML pages are scraped for "Seed Details" and "Instructions"
  sections (both use the `div.seed-details` CSS class).
  """

  import Ecto.Query
  alias BackyardGarden.{Repo, SupplierCatalog, SupplierCatalog.SupplierProduct}

  @base_url "https://brothernature.ca"
  @supplier "brother_nature"
  # Gift Cards and blank types are not seed products
  @excluded_types ["Gift Cards", ""]

  @req_options [
    retry: false,
    receive_timeout: 15_000
  ]

  @doc """
  Fetches all new/incomplete products, upserts them, and returns a
  `{upserted, skipped, errors}` count tuple. Products that already have
  care_html in the DB are skipped entirely — no HTTP fetch, no upsert.
  """
  def fetch_all_products do
    cached = existing_care_html_handles()
    fetch_page(1, {0, 0, 0}, cached)
  end

  @doc "Fetches a single product by handle, including care HTML scraped from the product page."
  def fetch_product(handle) do
    case find_in_catalog(handle) do
      {:ok, product} ->
        attrs = to_attrs(product)
        Map.put(attrs, :care_html, fetch_care_html(handle))

      {:error, reason} ->
        raise "Brother Nature fetch error: #{inspect(reason)}"
    end
  end

  defp find_in_catalog(handle, page \\ 1) do
    case get_json("#{@base_url}/products.json?limit=250&page=#{page}") do
      {:ok, %{"products" => []}} ->
        {:error, :not_found}

      {:ok, %{"products" => products}} ->
        case Enum.find(products, fn p -> p["handle"] == handle end) do
          nil -> find_in_catalog(handle, page + 1)
          product -> {:ok, product}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_page(page, counts, cached) do
    case get_json("#{@base_url}/products.json?limit=250&page=#{page}") do
      {:ok, %{"products" => []}} ->
        counts

      {:ok, %{"products" => products}} ->
        eligible = Enum.reject(products, &excluded_product?/1)
        Mix.shell().info("  Page #{page}: #{length(eligible)} products")
        new_counts = process_and_save(eligible, cached, counts)
        Process.sleep(3000)
        fetch_page(page + 1, new_counts, cached)

      {:error, reason} ->
        Mix.shell().error("Brother Nature fetch error: #{inspect(reason)}, stopping scrape")
        counts
    end
  end

  defp process_and_save(products, cached, {upserted, skipped, errors}) do
    Enum.reduce(products, {upserted, skipped, errors}, fn product, {u, s, e} ->
      attrs = to_attrs(product)
      handle = attrs[:handle]

      if MapSet.member?(cached, handle) do
        Mix.shell().info("  #{attrs[:title]} (skipped)")
        {u, s + 1, e}
      else
        Process.sleep(2000)
        care = fetch_care_html(handle)
        status = if care, do: "scraped", else: "no care guide"
        attrs_with_care = Map.put(attrs, :care_html, care)

        case upsert_with_retry(attrs_with_care) do
          {:ok, _} ->
            Mix.shell().info("  #{attrs[:title]} (#{status})")
            {u + 1, s, e}

          {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
            Mix.shell().error("  #{attrs[:title]} failed: #{inspect(changeset.errors)}")
            {u, s, e + 1}

          {:error, reason} ->
            Mix.shell().error("  #{attrs[:title]} failed: #{inspect(reason)}")
            {u, s, e + 1}
        end
      end
    end)
  end

  defp existing_care_html_handles do
    from(p in SupplierProduct,
      where: p.supplier == ^@supplier and not is_nil(p.care_html),
      select: p.handle
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp excluded_product?(product) do
    (product["product_type"] || "") in @excluded_types
  end

  defp fetch_care_html(handle) do
    case get_html("#{@base_url}/products/#{handle}") do
      {:ok, html} -> parse_care_html(html)
      {:error, _} -> nil
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

  defp upsert_with_retry(attrs, attempt \\ 1) do
    SupplierCatalog.upsert_supplier_product(attrs)
  rescue
    DBConnection.ConnectionError ->
      if attempt <= 3 do
        wait_s = attempt * 10
        Mix.shell().info("  DB connection lost, retrying in #{wait_s}s (attempt #{attempt}/3)...")
        Process.sleep(wait_s * 1_000)
        upsert_with_retry(attrs, attempt + 1)
      else
        {:error, :db_unavailable}
      end
  end

  defp get_json(url) do
    case Req.get(url, @req_options) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        preview = if is_binary(body), do: String.slice(body, 0, 200), else: inspect(body)
        {:error, {:http_error, status, preview}}

      {:error, err} ->
        {:error, err}
    end
  end

  defp get_html(url) do
    case Req.get(url, [{:headers, [{"accept", "text/html"}]} | @req_options]) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, err} ->
        {:error, err}
    end
  end
end
