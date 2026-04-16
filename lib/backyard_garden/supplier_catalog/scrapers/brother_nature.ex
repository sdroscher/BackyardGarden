defmodule BackyardGarden.SupplierCatalog.Scrapers.BrotherNature do
  @moduledoc """
  Fetches all products from the Brother Nature Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  Per-product HTML pages are scraped for "Seed Details" and "Instructions"
  sections (both use the `div.seed-details` CSS class).

  Uses curl instead of Req for all HTTP requests. brothernature.ca is behind
  Cloudflare, which blocks Erlang's TLS fingerprint but allows curl's.
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
    case curl_json("#{@base_url}/products/#{handle}.json") do
      {:ok, %{"product" => product}} ->
        attrs = to_attrs(product)
        Map.put(attrs, :care_html, fetch_care_html(handle))

      {:error, reason} ->
        raise "Brother Nature fetch error: #{inspect(reason)}"
    end
  end

  defp fetch_page(page, acc) do
    case curl_json("#{@base_url}/products.json?limit=250&page=#{page}") do
      {:ok, %{"products" => []}} ->
        acc

      {:ok, %{"products" => products}} ->
        new_attrs = process_products(products)
        Process.sleep(3000)
        fetch_page(page + 1, acc ++ new_attrs)

      {:error, reason} ->
        Mix.shell().error("Brother Nature fetch error: #{inspect(reason)}, stopping scrape")
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
    case curl_html("#{@base_url}/products/#{handle}") do
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

  @curl_user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"

  # Fetches a URL via curl and decodes the JSON response body.
  # Uses curl because brothernature.ca is behind Cloudflare, which blocks
  # Erlang's TLS fingerprint but allows curl's (OpenSSL-based).
  defp curl_json(url) do
    case System.cmd(
           "curl",
           ["-s", "--max-time", "15", "-A", @curl_user_agent, url],
           stderr_to_stdout: false
         ) do
      {body, 0} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            {:ok, decoded}

          {:error, _} ->
            {:error, {:invalid_json, String.slice(body, 0, 200)}}
        end

      {_, exit_code} ->
        {:error, {:curl_exit, exit_code}}
    end
  end

  # Fetches a URL via curl and returns the raw HTML body.
  defp curl_html(url) do
    case System.cmd(
           "curl",
           ["-s", "--max-time", "15", "-L", "-A", @curl_user_agent, url],
           stderr_to_stdout: false
         ) do
      {body, 0} -> {:ok, body}
      {_, exit_code} -> {:error, {:curl_exit, exit_code}}
    end
  end
end
