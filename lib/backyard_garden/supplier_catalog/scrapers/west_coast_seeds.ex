defmodule BackyardGarden.SupplierCatalog.Scrapers.WestCoastSeeds do
  @moduledoc """
  Fetches all products from the West Coast Seeds Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  import Ecto.Query
  alias BackyardGarden.{Repo, SupplierCatalog, SupplierCatalog.SupplierProduct}

  @base_url "https://www.westcoastseeds.com"
  @supplier "west_coast_seeds"
  @excluded_sections ~w[Latin Difficulty]

  @doc """
  Fetches all new/incomplete products, upserts them, and returns a
  `{upserted, skipped, errors}` count tuple. Products that already have
  care_html in the DB are skipped entirely — no HTTP fetch, no upsert.
  """
  def fetch_all_products do
    cached = existing_care_html_handles()
    fetch_page(1, {0, 0, 0}, cached)
  end

  @doc "Fetches a single product by handle, including the care guide scraped from the product page."
  def fetch_product(handle) do
    case Req.get("#{@base_url}/products/#{handle}.json",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        attrs = to_attrs(body["product"])
        Map.put(attrs, :care_html, fetch_care_guide(handle))

      {:ok, %{status: 429}} ->
        raise "West Coast Seeds rate limited (429) — try again later"

      {:ok, %{status: 404}} ->
        raise "Product not found on West Coast Seeds (404)"

      {:ok, %{status: status}} ->
        raise "West Coast Seeds returned status #{status}"

      {:error, reason} ->
        raise "West Coast Seeds connection error: #{inspect(reason)}"
    end
  end

  defp fetch_page(page, counts, cached) do
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
            eligible = Enum.filter(products, &seed_product?/1)
            Mix.shell().info("  Page #{page}: #{length(eligible)} seed products")
            new_counts = process_and_save(eligible, cached, counts)
            Process.sleep(3000)
            fetch_page(page + 1, new_counts, cached)
        end

      {:ok, %{status: 429}} ->
        Mix.shell().error("West Coast Seeds rate limited (429), stopping scrape")
        counts

      {:ok, %{status: status}} ->
        Mix.shell().error("West Coast Seeds API returned status #{status}, stopping scrape")
        counts

      {:error, reason} ->
        Mix.shell().error("West Coast Seeds API error: #{inspect(reason)}, stopping scrape")
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
        care = fetch_care_guide(handle)
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

  # Fetches the product HTML page and parses the "All About" accordion sections.
  # Returns nil if the section is absent or all sections are empty.
  defp fetch_care_guide(handle) do
    case Req.get("#{@base_url}/products/#{handle}",
           receive_timeout: 15_000,
           headers: user_agent_headers(),
           retry: false
         ) do
      {:ok, %{body: html}} when is_binary(html) ->
        parse_care_guide(html)

      _ ->
        nil
    end
  end

  defp parse_care_guide(html) do
    {:ok, document} = Floki.parse_document(html)

    sections =
      document
      |> Floki.find("#all-about .accordion-container-htg")
      |> Enum.flat_map(&section_to_html/1)

    if sections == [], do: nil, else: Enum.join(sections, "\n")
  end

  defp section_to_html(container) do
    heading =
      container
      |> Floki.find(".accordion strong")
      |> Floki.text()
      |> String.trim()

    content_nodes = Floki.find(container, ".content-wrap")

    excluded = heading in @excluded_sections
    empty = Floki.text(content_nodes) |> String.trim() == ""

    if excluded or empty do
      []
    else
      ["<div>#{Floki.raw_html(content_nodes)}</div>"]
    end
  end

  # West Coast Seeds sells non-seed products (books, tools, soil amendments, etc.).
  # Only import products whose type contains "seed" to keep the catalog relevant.
  defp seed_product?(product) do
    product_type = product["product_type"] || ""
    String.contains?(String.downcase(product_type), "seed")
  end

  defp to_attrs(product) do
    %{
      supplier: @supplier,
      shopify_product_id: product["id"],
      handle: product["handle"],
      title: product["title"],
      product_type: product["product_type"],
      tags: normalize_tags(product["tags"]),
      description_html: clean_description(product["body_html"]),
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # West Coast Seeds embeds Shopify shortcode tags like [description action="start"]
  # that only render inside their storefront. Strip them before storing.
  defp clean_description(nil), do: nil
  defp clean_description(html), do: Regex.replace(~r/\[[^\]]+\]/, html, "")

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
