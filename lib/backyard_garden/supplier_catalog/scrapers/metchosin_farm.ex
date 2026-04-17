defmodule BackyardGarden.SupplierCatalog.Scrapers.MetchosinFarm do
  @moduledoc """
  Fetches all products from the Metchosin Farm Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  import Ecto.Query
  alias BackyardGarden.{Repo, SupplierCatalog, SupplierCatalog.SupplierProduct}

  @base_url "https://metchosinfarm.ca"
  @supplier "metchosin_farm"

  @doc """
  Fetches all products not yet in the DB, upserts them, and returns a
  `{upserted, skipped, errors}` count tuple. Products already in the DB
  are skipped — no HTTP fetch, no upsert.
  """
  def fetch_all_products do
    existing = existing_handles()
    fetch_page(1, {0, 0, 0}, existing)
  end

  @doc "Fetches a single product by handle and returns its attribute map."
  def fetch_product(handle) do
    Process.sleep(1000)

    case Req.get("#{@base_url}/products/#{handle}.json",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        to_attrs(body["product"])

      {:ok, %{status: 429}} ->
        raise "Metchosin Farm rate limited (429) — try again later"

      {:ok, %{status: 404}} ->
        raise "Product not found on Metchosin Farm (404)"

      {:ok, %{status: status}} ->
        raise "Metchosin Farm returned status #{status}"

      {:error, reason} ->
        raise "Metchosin Farm connection error: #{inspect(reason)}"
    end
  end

  defp fetch_page(page, counts, existing) do
    case Req.get("#{@base_url}/products.json?limit=250&page=#{page}",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        case body["products"] do
          [] ->
            counts

          products ->
            Mix.shell().info("  Page #{page}: #{length(products)} products")
            new_counts = process_and_save(products, existing, counts)
            Process.sleep(5000)
            fetch_page(page + 1, new_counts, existing)
        end

      {:ok, %{status: 429}} ->
        Mix.shell().error("Metchosin Farm rate limited (429), stopping scrape")
        counts

      {:ok, %{status: status}} ->
        Mix.shell().error("Metchosin Farm API returned status #{status}, stopping scrape")
        counts

      {:error, reason} ->
        Mix.shell().error("Metchosin Farm API error: #{inspect(reason)}, stopping scrape")
        counts
    end
  end

  defp process_and_save(products, existing, counts) do
    Enum.reduce(products, counts, fn product, acc ->
      attrs = to_attrs(product)

      if MapSet.member?(existing, attrs[:handle]),
        do: skip_product(attrs, acc),
        else: upsert_product(attrs, acc)
    end)
  end

  # Metchosin Farm has no per-product HTML to scrape, so any existing handle
  # means the product is already fully saved — skip it entirely.
  defp existing_handles do
    from(p in SupplierProduct,
      where: p.supplier == ^@supplier,
      select: p.handle
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp skip_product(attrs, {u, s, e}) do
    Mix.shell().info("  #{attrs[:title]} (skipped)")
    {u, s + 1, e}
  end

  defp upsert_product(attrs, {u, s, e}) do
    case upsert_with_retry(attrs) do
      {:ok, _} ->
        Mix.shell().info("  #{attrs[:title]} (saved)")
        {u + 1, s, e}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        Mix.shell().error("  #{attrs[:title]} failed: #{inspect(changeset.errors)}")
        {u, s, e + 1}

      {:error, reason} ->
        Mix.shell().error("  #{attrs[:title]} failed: #{inspect(reason)}")
        {u, s, e + 1}
    end
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

  # Shopify returns tags as a list; store as a comma-separated string.
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

  # Browser-like headers to avoid bot detection and rate limiting
  defp user_agent_headers do
    [
      {"user-agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"},
      {"accept",
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"},
      {"accept-encoding", "gzip, deflate"},
      {"accept-language", "en-US,en;q=0.9"},
      {"cache-control", "max-age=0"},
      {"priority", "u=0, i"},
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
