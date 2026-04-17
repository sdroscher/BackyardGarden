defmodule BackyardGarden.SupplierCatalogTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.Seeds

  defp product_fixture(attrs) do
    defaults = %{
      supplier: "metchosin_farm",
      shopify_product_id: 12_345,
      handle: "mullein",
      title: "Mullein",
      url: "https://metchosinfarm.ca/products/mullein",
      scraped_at: ~U[2026-04-01 00:00:00Z]
    }

    {:ok, product} = SupplierCatalog.upsert_supplier_product(Map.merge(defaults, attrs))
    product
  end

  describe "upsert_supplier_product/1" do
    test "inserts a new supplier product" do
      attrs = %{
        supplier: "west_coast_seeds",
        shopify_product_id: 99_999,
        handle: "desert-organic",
        title: "Desert Organic",
        url: "https://www.westcoastseeds.com/products/desert-organic",
        scraped_at: ~U[2026-04-01 00:00:00Z]
      }

      assert {:ok, product} = SupplierCatalog.upsert_supplier_product(attrs)
      assert product.title == "Desert Organic"
      assert product.supplier == "west_coast_seeds"
    end

    test "updates an existing product on duplicate supplier + shopify_product_id" do
      attrs = %{
        supplier: "metchosin_farm",
        shopify_product_id: 12_345,
        handle: "mullein",
        title: "Mullein",
        url: "https://metchosinfarm.ca/products/mullein",
        scraped_at: ~U[2026-04-01 00:00:00Z]
      }

      {:ok, _} = SupplierCatalog.upsert_supplier_product(attrs)

      {:ok, updated} =
        SupplierCatalog.upsert_supplier_product(Map.put(attrs, :title, "Mullein (Updated)"))

      assert updated.title == "Mullein (Updated)"
      assert length(BackyardGarden.Repo.all(BackyardGarden.SupplierCatalog.SupplierProduct)) == 1
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, changeset} = SupplierCatalog.upsert_supplier_product(%{})
      assert %{supplier: _} = errors_on(changeset)
    end
  end

  describe "list_supplier_products/1" do
    test "returns all products ordered by title when no filters" do
      product_fixture(%{title: "Zucchini", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      titles = SupplierCatalog.list_supplier_products() |> Enum.map(& &1.title)
      assert titles == ["Basil", "Zucchini"]
    end

    test "filters by supplier" do
      product_fixture(%{supplier: "metchosin_farm", shopify_product_id: 1, title: "Mullein"})

      product_fixture(%{
        supplier: "west_coast_seeds",
        shopify_product_id: 2,
        title: "Desert Squash"
      })

      products = SupplierCatalog.list_supplier_products(%{supplier: "metchosin_farm"})
      assert length(products) == 1
      assert hd(products).title == "Mullein"
    end

    test "searches by title (case-insensitive)" do
      product_fixture(%{title: "Purple Mullein", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      products = SupplierCatalog.list_supplier_products(%{search: "mullein"})
      assert length(products) == 1
      assert hd(products).title == "Purple Mullein"
    end
  end

  describe "fetch_and_upsert_by_url/1" do
    test "returns error for unrecognised supplier URL" do
      assert {:error, msg} =
               SupplierCatalog.fetch_and_upsert_by_url("https://example.com/products/foo")

      assert msg =~ "brothernature.ca"
    end
  end

  describe "find_match_for_seed/1" do
    test "returns the best-matching supplier product and its score" do
      product_fixture(%{title: "Bush Bean Mix", shopify_product_id: 1})
      product_fixture(%{title: "Basil", shopify_product_id: 2})
      user = BackyardGarden.Test.Fixtures.user_fixture()
      {:ok, seed} = Seeds.create_seed_for_user(user.id, %{"name" => "Bush Beans - Mix"})
      {product, score} = SupplierCatalog.find_match_for_seed(seed)
      assert product.title == "Bush Bean Mix"
      assert score > 0.75
    end

    test "returns {nil, 0.0} when the supplier_products table is empty" do
      user = BackyardGarden.Test.Fixtures.user_fixture()
      {:ok, seed} = Seeds.create_seed_for_user(user.id, %{"name" => "Tomato"})
      assert {nil, +0.0} = SupplierCatalog.find_match_for_seed(seed)
    end
  end
end
