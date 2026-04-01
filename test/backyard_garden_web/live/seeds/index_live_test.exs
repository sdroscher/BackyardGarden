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
      |> form("#filter-form", %{"type" => "", "brand" => "West Coast Seeds", "cycle" => "", "search" => ""})
      |> render_change()

    assert html =~ "Carrots"
    refute html =~ "Basil"
    refute html =~ "Echinacea"
  end

  test "filters by cycle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    html =
      view
      |> form("#filter-form", %{"type" => "", "brand" => "", "cycle" => "Perennial", "search" => ""})
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
      |> form("#filter-form", %{"type" => "", "brand" => "", "cycle" => "", "search" => "zzznomatch"})
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
end
