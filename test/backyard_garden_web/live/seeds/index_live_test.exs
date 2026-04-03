defmodule BackyardGardenWeb.Seeds.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds

  setup do
    {:ok, basil} =
      Seeds.create_seed(%{
        name: "Basil",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Annual",
        ideal_planting_time: "Spring"
      })

    {:ok, carrots} =
      Seeds.create_seed(%{
        name: "Carrots",
        brand: "West Coast Seeds",
        type: "Vegetable",
        cycle: "Annual",
        ideal_planting_time: "Early Spring"
      })

    {:ok, echinacea} =
      Seeds.create_seed(%{
        name: "Echinacea",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Perennial",
        ideal_planting_time: "Early Spring"
      })

    %{basil: basil, carrots: carrots, echinacea: echinacea}
  end

  test "renders all seeds", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "Basil"
    assert html =~ "Carrots"
    assert html =~ "Echinacea"
  end

  test "shows seed count", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "3 seeds"
  end

  test "filters by type via form change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "Herb", "brand" => "", "cycle" => "", "search" => ""})
      |> render_change()

    assert html =~ "Basil"
    assert html =~ "Echinacea"
    refute html =~ "Carrots"
    assert html =~ "2 seeds"
  end

  test "filters by brand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{
        "type" => "",
        "brand" => "West Coast Seeds",
        "cycle" => "",
        "search" => ""
      })
      |> render_change()

    assert html =~ "Carrots"
    refute html =~ "Basil"
    refute html =~ "Echinacea"
  end

  test "filters by cycle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{
        "type" => "",
        "brand" => "",
        "cycle" => "Perennial",
        "search" => ""
      })
      |> render_change()

    assert html =~ "Echinacea"
    refute html =~ "Basil"
    refute html =~ "Carrots"
  end

  test "searches by name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "", "brand" => "", "cycle" => "", "search" => "carr"})
      |> render_change()

    assert html =~ "Carrots"
    refute html =~ "Basil"
  end

  test "each row links to seed detail", %{conn: conn, basil: basil} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ ~p"/seeds/#{basil.id}"
  end

  test "shows empty state when no seeds match filter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{
        "type" => "",
        "brand" => "",
        "cycle" => "",
        "search" => "zzznomatch"
      })
      |> render_change()

    assert html =~ "0 seeds"
    refute html =~ "Basil"
    refute html =~ "Carrots"
    refute html =~ "Echinacea"
  end

  test "combined type and brand filter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{
        "type" => "Herb",
        "brand" => "Metchosin Farm",
        "cycle" => "",
        "search" => ""
      })
      |> render_change()

    assert html =~ "Basil"
    assert html =~ "Echinacea"
    refute html =~ "Carrots"
  end

  test "sort event sorts by field ascending", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html = render_click(view, "sort", %{"field" => "type"})

    # Herb < Vegetable alphabetically, so Basil and Echinacea (Herb) come before Carrots (Vegetable)
    basil_pos = :binary.match(html, "Basil") |> elem(0)
    carrots_pos = :binary.match(html, "Carrots") |> elem(0)
    assert basil_pos < carrots_pos
  end

  test "sort event toggles direction on second click", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    # First click: sort by name asc (default is already name asc, but explicit)
    render_click(view, "sort", %{"field" => "name"})
    # Second click on same field: name desc — Echinacea should come first
    html = render_click(view, "sort", %{"field" => "name"})

    echinacea_pos = :binary.match(html, "Echinacea") |> elem(0)
    basil_pos = :binary.match(html, "Basil") |> elem(0)
    assert echinacea_pos < basil_pos
  end

  test "sort event resets to asc when switching fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    # Sort by name desc first
    render_click(view, "sort", %{"field" => "name"})
    render_click(view, "sort", %{"field" => "name"})
    # Now switch to type — should be asc (Herb before Vegetable)
    html = render_click(view, "sort", %{"field" => "type"})

    basil_pos = :binary.match(html, "Basil") |> elem(0)
    carrots_pos = :binary.match(html, "Carrots") |> elem(0)
    assert basil_pos < carrots_pos
  end

  test "renders planting_method dropdown", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "planting_method"
  end

  test "renders sun_requirement dropdown", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ "sun_requirement"
  end

  test "filters by planting_method", %{conn: conn} do
    {:ok, direct_sow} =
      Seeds.create_seed(%{
        name: "Direct Sow Seed",
        planting_method: "Direct Sow",
        type: "Vegetable"
      })

    {:ok, seedlings} =
      Seeds.create_seed(%{name: "Seedlings Seed", planting_method: "Seedlings", type: "Herb"})

    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{
        "type" => "",
        "brand" => "",
        "cycle" => "",
        "planting_method" => "Direct Sow",
        "sun_requirement" => "",
        "search" => ""
      })
      |> render_change()

    assert html =~ direct_sow.name
    refute html =~ seedlings.name
  end
end
