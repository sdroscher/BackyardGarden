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
    %{body: body} = Req.get!("#{@base_url}/products/#{handle}.json", receive_timeout: 15_000)
    to_attrs(body["product"])
  end

  defp fetch_page(page, acc) do
    %{body: body} =
      Req.get!("#{@base_url}/products.json?limit=250&page=#{page}", receive_timeout: 15_000)

    case body["products"] do
      [] -> acc
      products ->
        Process.sleep(500)  # Rate limiting: 500ms delay between pages
        fetch_page(page + 1, acc ++ Enum.map(products, &to_attrs/1))
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
end
