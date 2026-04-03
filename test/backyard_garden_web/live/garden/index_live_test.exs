defmodule BackyardGardenWeb.Garden.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.GardenZones
  alias BackyardGarden.Plantings
  alias BackyardGarden.Seeds

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", type: "Vegetable", cycle: "Annual", maturity_days: 50}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs \\ %{}) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  test "renders My Garden heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "My Garden"
  end

  test "shows PLANTED section with planting", %{conn: conn} do
    seed = seed_fixture(%{name: "Spinach"})
    planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Spinach"
    assert html =~ "planted"
  end

  test "shows PLANNED section with planting", %{conn: conn} do
    seed = seed_fixture(%{name: "Carrots"})
    planting_fixture(seed, %{status: "planned"})

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Carrots"
  end

  test "shows HARVESTED section", %{conn: conn} do
    seed = seed_fixture(%{name: "Lettuce"})

    planting_fixture(seed, %{
      status: "harvested",
      planted_at: ~D[2026-03-01],
      harvested_at: ~D[2026-04-01]
    })

    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Lettuce"
  end

  test "shows Log Planting button", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ "Log Planting"
  end

  test "mark planted action updates status", %{conn: conn} do
    seed = seed_fixture(%{name: "Basil"})
    planting = planting_fixture(seed, %{status: "planned"})

    {:ok, view, _html} = live(conn, ~p"/garden")
    html = render_click(view, "mark_planted", %{"id" => planting.id})
    assert html =~ "planted"
  end

  test "mark harvested action updates status", %{conn: conn} do
    seed = seed_fixture(%{name: "Basil"})
    planting = planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, view, _html} = live(conn, ~p"/garden")
    html = render_click(view, "mark_harvested", %{"id" => planting.id})
    assert html =~ "harvested"
  end

  test "shows zone recommendations when seed is selected in form", %{conn: conn} do
    {:ok, _zone} =
      GardenZones.create_zone(%{
        name: "Sunny Raised Planters",
        sun_exposures: "full_sun",
        allowed_types: "Vegetable",
        allowed_cycles: "Annual"
      })

    seed =
      seed_fixture(%{
        name: "Beans",
        type: "Vegetable",
        cycle: "Annual",
        sun_requirement: "full_sun"
      })

    {:ok, view, _html} = live(conn, ~p"/garden")
    render_click(view, "show_form", %{})

    html =
      view
      |> form("#log-planting-form", %{"planting" => %{"seed_id" => seed.id}})
      |> render_change()

    assert html =~ "Sunny Raised Planters"
  end
end
