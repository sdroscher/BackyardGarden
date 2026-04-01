defmodule BackyardGarden.SupplierCatalog.Scrapers.WestCoastSeeds do
  @moduledoc """
  Fetches all products from the West Coast Seeds Shopify catalog.
  Uses the public /products.json endpoint, paginated by page number.
  """

  @base_url "https://www.westcoastseeds.com"
  @supplier "west_coast_seeds"

  @doc "Returns a list of attribute maps ready for SupplierCatalog.upsert_supplier_product/1."
  def fetch_all_products do
    fetch_page(1, [])
  end

  defp fetch_page(page, acc) do
    %{body: body} = Req.get!("#{@base_url}/products.json?limit=250&page=#{page}")

    case body["products"] do
      [] ->
        acc

      products ->
        seed_products = Enum.filter(products, &seed_product?/1)
        fetch_page(page + 1, acc ++ Enum.map(seed_products, &to_attrs/1))
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
      description_html: product["body_html"],
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Shopify returns tags as a list; store as a comma-separated string.
  defp normalize_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp normalize_tags(tags), do: tags
end
