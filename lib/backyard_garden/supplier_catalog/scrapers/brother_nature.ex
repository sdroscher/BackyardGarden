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
    products
    |> Enum.reject(&excluded_product?/1)
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
