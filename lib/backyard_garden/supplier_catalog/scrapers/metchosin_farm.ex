defmodule BackyardGarden.SupplierCatalog.Scrapers.MetchosinFarm do
  @moduledoc """
  Fetches all products from the Metchosin Farm Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  @base_url "https://metchosinfarm.ca"
  @supplier "metchosin_farm"

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  @doc "Fetches a single product by handle and returns its attribute map."
  def fetch_product(handle) do
    case Req.get("#{@base_url}/products/#{handle}.json",
      receive_timeout: 15_000,
      headers: user_agent_header(),
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

  defp fetch_page(page, acc) do
    case Req.get("#{@base_url}/products.json?limit=250&page=#{page}",
      receive_timeout: 15_000,
      headers: user_agent_header(),
      retry: false
    ) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 and is_map(body) ->
        case body["products"] do
          [] -> acc
          products ->
            Process.sleep(2000)  # Rate limiting: 2s delay between pages
            fetch_page(page + 1, acc ++ Enum.map(products, &to_attrs/1))
        end

      {:ok, %{status: 429}} ->
        Mix.shell().error("Metchosin Farm rate limited (429), stopping scrape")
        acc

      {:ok, %{status: status}} ->
        Mix.shell().error("Metchosin Farm API returned status #{status}, stopping scrape")
        acc

      {:error, reason} ->
        Mix.shell().error("Metchosin Farm API error: #{inspect(reason)}, stopping scrape")
        acc
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

  # User-agent header to avoid Cloudflare blocks
  defp user_agent_header do
    [{"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}]
  end
end
