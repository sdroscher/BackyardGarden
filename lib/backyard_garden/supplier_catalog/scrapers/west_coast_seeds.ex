defmodule BackyardGarden.SupplierCatalog.Scrapers.WestCoastSeeds do
  @moduledoc """
  Fetches all products from the West Coast Seeds Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  @base_url "https://www.westcoastseeds.com"
  @supplier "west_coast_seeds"
  @excluded_sections ~w[Latin Difficulty]

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  @doc "Fetches a single product by handle, including the care guide scraped from the product page."
  def fetch_product(handle) do
    case Req.get("#{@base_url}/products/#{handle}.json",
      receive_timeout: 15_000,
      headers: user_agent_header(),
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

  # Fetches the product HTML page and parses the "All About" accordion sections.
  # Returns nil if the section is absent or all sections are empty.
  defp fetch_care_guide(handle) do
    case Req.get("#{@base_url}/products/#{handle}",
      receive_timeout: 15_000,
      headers: user_agent_header(),
      retry: false
    ) do
      {:ok, %{body: html}} when is_binary(html) ->
        parse_care_guide(html)

      _ ->
        nil
    end
  end

  # User-agent header to avoid Cloudflare blocks
  defp user_agent_header do
    [{"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}]
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

  defp fetch_page(page, acc) do
    case Req.get("#{@base_url}/products.json?limit=250&page=#{page}",
      receive_timeout: 15_000,
      headers: user_agent_header(),
      retry: false
    ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        case body["products"] do
          [] ->
            acc

          products ->
            seed_products = Enum.filter(products, &seed_product?/1)

            new_attrs =
              seed_products
              |> Task.async_stream(
                fn product ->
                  attrs = to_attrs(product)
                  Map.put(attrs, :care_html, fetch_care_guide(attrs[:handle]))
                end,
                max_concurrency: 2,
                timeout: 20_000
              )
              |> Enum.map(fn {:ok, attrs} -> attrs end)

            Process.sleep(3000)  # Rate limiting: 3s delay between pages
            fetch_page(page + 1, acc ++ new_attrs)
        end

      {:ok, %{status: 429}} ->
        acc

      {:ok, %{status: _status}} ->
        acc

      {:error, _reason} ->
        acc
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
end
