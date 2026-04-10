defmodule BackyardGardenWeb.Seeds.ShowLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds
  alias BackyardGarden.SupplierCatalog
  alias BackyardGarden.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    conn = log_in_user(conn, user)

    {:ok, seed} =
      Seeds.create_seed(%{
        name: "Purple Basil",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Annual",
        planting_method: "Seedlings",
        ideal_planting_time: "Late April/Early May",
        maturity_days: 60,
        notes: "Great companion plant"
      })

    %{conn: conn, seed: seed}
  end

  test "renders seed name and all present fields", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")

    assert html =~ "Purple Basil"
    assert html =~ "Metchosin Farm"
    assert html =~ "Herb"
    assert html =~ "Annual"
    assert html =~ "Seedlings"
    assert html =~ "Late April/Early May"
    assert html =~ "60"
    assert html =~ "Great companion plant"
  end

  test "shows a back link to the seed library", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    assert html =~ ~p"/seeds"
  end

  test "sets page title to seed name", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    assert html =~ "Purple Basil"
    assert html =~ "BackyardGarden"
  end

  test "does not render optional fields when nil", %{conn: conn} do
    {:ok, seed_no_notes} =
      Seeds.create_seed(%{name: "Plain Seed", type: "Vegetable", cycle: "Annual"})

    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed_no_notes.id}")

    assert html =~ "Plain Seed"
    # notes section should not appear when notes is nil
    refute html =~ "Notes"
  end

  test "returns 404 for unknown id", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/seeds/#{Ecto.UUID.generate()}")
    end
  end

  test "renders supplier section when seed is linked to a supplier product", %{conn: conn} do
    {:ok, product} =
      SupplierCatalog.upsert_supplier_product(%{
        supplier: "metchosin_farm",
        shopify_product_id: 11_111,
        handle: "purple-basil",
        title: "Purple Basil",
        description_html: "<p>Great companion plant for tomatoes.</p>",
        url: "https://metchosinfarm.ca/products/purple-basil",
        scraped_at: ~U[2026-04-01 00:00:00Z]
      })

    {:ok, seed} =
      Seeds.create_seed(%{name: "Purple Basil", type: "Herb", supplier_product_id: product.id})

    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")

    assert html =~ "From the Supplier"
    assert html =~ "Great companion plant for tomatoes."
    assert html =~ "metchosinfarm.ca/products/purple-basil"
  end

  test "does not render supplier section when seed has no supplier product", %{
    conn: conn,
    seed: seed
  } do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    refute html =~ "From the Supplier"
  end

  test "shows in-season badge when seed window includes current month", %{conn: conn} do
    today = Date.utc_today()
    month_name = Calendar.strftime(today, "%B") |> String.downcase()

    {:ok, seed} =
      Seeds.create_seed(%{name: "In Season Herb", type: "Herb", ideal_planting_time: month_name})

    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    assert html =~ "In season"
  end

  test "shows Log Planting button", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
    assert html =~ "Log Planting"
  end

  test "clicking Log Planting shows the inline form", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}")
    html = render_click(view, "show_log_form", %{})
    assert html =~ "Save Planting"
    assert html =~ "Date planted"
  end

  test "submitting log form creates a planting", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}")
    render_click(view, "show_log_form", %{})

    view
    |> form("[id=log-planting-form]", %{
      "planting" => %{
        "seed_id" => seed.id,
        "status" => "planted",
        "planted_at" => to_string(Date.utc_today()),
        "location" => "",
        "notes" => "",
        "zone_id" => ""
      }
    })
    |> render_submit()

    # Flash appears — check the response
    html = render(view)
    assert html =~ "Planting logged"
  end
end
