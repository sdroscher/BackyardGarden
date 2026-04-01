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
      [] -> acc
      products -> fetch_page(page + 1, acc ++ Enum.map(products, &to_attrs/1))
    end
  end

  defp to_attrs(product) do
    %{
      supplier: @supplier,
      shopify_product_id: product["id"],
      handle: product["handle"],
      title: product["title"],
      product_type: product["product_type"],
      tags: product["tags"],
      description_html: product["body_html"],
      url: "#{@base_url}/products/#{product["handle"]}",
      scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
