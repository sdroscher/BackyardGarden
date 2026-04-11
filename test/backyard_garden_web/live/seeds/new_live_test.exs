defmodule BackyardGardenWeb.Seeds.NewLiveTest do
  @moduledoc false

  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds
  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp supplier_product_fixture(attrs) do
    defaults = %{
      supplier: "west_coast_seeds",
      shopify_product_id: System.unique_integer([:positive]),
      handle: "test-product-#{System.unique_integer([:positive])}",
      title: "Test Product",
      url: "https://www.westcoastseeds.com/products/test",
      scraped_at: ~U[2026-04-01 00:00:00Z]
    }

    {:ok, product} = SupplierCatalog.upsert_supplier_product(Map.merge(defaults, attrs))
    product
  end

  test "renders mode tabs", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds/new")
    assert html =~ "Supplier Catalog"
    assert html =~ "From URL"
    assert html =~ "Enter Manually"
  end

  test "defaults to catalog mode showing supplier products", %{conn: conn} do
    supplier_product_fixture(%{title: "Kale Mix"})
    {:ok, _view, html} = live(conn, ~p"/seeds/new")
    assert html =~ "Kale Mix"
  end

  test "supplier toggle buttons are shown in catalog mode", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds/new")
    assert html =~ "West Coast Seeds"
    assert html =~ "Metchosin Farm"
  end

  test "toggling a supplier off hides its products", %{conn: conn} do
    supplier_product_fixture(%{
      title: "Kale Mix",
      handle: "kale-mix",
      supplier: "west_coast_seeds"
    })

    supplier_product_fixture(%{
      title: "Purple Basil",
      handle: "purple-basil",
      supplier: "metchosin_farm"
    })

    {:ok, view, _html} = live(conn, ~p"/seeds/new")

    html = render_click(view, "toggle_supplier", %{"supplier" => "west_coast_seeds"})
    refute html =~ "Kale Mix"
    assert html =~ "Purple Basil"
  end

  test "toggling a supplier back on shows its products again", %{conn: conn} do
    supplier_product_fixture(%{
      title: "Kale Mix",
      handle: "kale-mix",
      supplier: "west_coast_seeds"
    })

    {:ok, view, _html} = live(conn, ~p"/seeds/new")

    render_click(view, "toggle_supplier", %{"supplier" => "west_coast_seeds"})
    html = render_click(view, "toggle_supplier", %{"supplier" => "west_coast_seeds"})
    assert html =~ "Kale Mix"
  end

  test "search filters supplier catalog results", %{conn: conn} do
    supplier_product_fixture(%{title: "Kale Mix", handle: "kale-mix"})
    supplier_product_fixture(%{title: "Tomato Roma", handle: "tomato-roma"})

    {:ok, view, _html} = live(conn, ~p"/seeds/new")

    html = render_keyup(view, "search_catalog", %{"value" => "kale"})
    assert html =~ "Kale Mix"
    refute html =~ "Tomato Roma"
  end

  test "selecting a supplier product pre-fills the form", %{conn: conn} do
    product = supplier_product_fixture(%{title: "Purple Basil", handle: "purple-basil"})

    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    html = render_click(view, "select_supplier_product", %{"id" => product.id})

    assert html =~ "Purple Basil"
    assert html =~ "West Coast Seeds"
  end

  test "saving after catalog selection preserves supplier_product_id on the seed", %{
    conn: conn,
    user: user
  } do
    product =
      supplier_product_fixture(%{
        title: "Cherry Tomato",
        handle: "cherry-tomato",
        description_html: "<p>Great for containers.</p>"
      })

    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    render_click(view, "select_supplier_product", %{"id" => product.id})

    view
    |> form("#seed-new-form", %{"seed" => %{"type" => "Vegetable", "cycle" => "Annual"}})
    |> render_submit()

    seed = Seeds.list_seeds(user.id) |> Enum.find(&(&1.name == "Cherry Tomato"))
    assert seed != nil
    assert seed.supplier_product_id == product.id
  end

  test "switching to URL mode shows URL input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    html = render_click(view, "set_mode", %{"mode" => "url"})
    assert html =~ "westcoastseeds.com"
    assert html =~ "Fetch"
  end

  test "set_url captures the typed URL value", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    render_click(view, "set_mode", %{"mode" => "url"})

    render_keyup(view, "set_url", %{"value" => "https://www.westcoastseeds.com/products/kale"})

    # Fetch button should become enabled (url_input is no longer empty)
    html = render(view)
    refute html =~ ~s(disabled="disabled")
  end

  test "switching to manual mode hides catalog panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    html = render_click(view, "set_mode", %{"mode" => "manual"})
    refute html =~ "Browse Supplier Catalog"
    refute html =~ "Import from URL"
  end

  test "saving a valid seed redirects to show page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds/new")
    render_click(view, "set_mode", %{"mode" => "manual"})

    {:ok, _show_view, html} =
      view
      |> form("#seed-new-form", %{
        "seed" => %{"name" => "Spinach", "type" => "Vegetable", "cycle" => "Annual"}
      })
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "Spinach"
    assert html =~ "added to your library"
  end

  test "validation error shown when name is blank", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds/new")

    html =
      view
      |> form("#seed-new-form", %{"seed" => %{"name" => ""}})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end

  test "new seed is scoped to current user", %{conn: conn, user: user} do
    other_user = Fixtures.user_fixture()

    {:ok, view, _html} = live(conn, ~p"/seeds/new")

    view
    |> form("#seed-new-form", %{
      "seed" => %{"name" => "My Basil", "type" => "Herb", "cycle" => "Annual"}
    })
    |> render_submit()

    seeds = Seeds.list_seeds(user.id)
    assert Enum.any?(seeds, &(&1.name == "My Basil"))

    other_seeds = Seeds.list_seeds(other_user.id)
    refute Enum.any?(other_seeds, &(&1.name == "My Basil"))
  end
end
