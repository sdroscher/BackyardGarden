defmodule BackyardGardenWeb.Dashboard.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.{Seeds, Plantings}
  alias BackyardGarden.Weather.Cache
  alias BackyardGarden.Test.Fixtures

  setup %{conn: conn} do
    Cache.clear()
    user = Fixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp seed_fixture(attrs) do
    defaults = %{name: "Test Seed", type: "Vegetable", cycle: "Annual", maturity_days: 50}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  test "renders the dashboard page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Plant Now"
    assert html =~ "Recently Planted"
    assert html =~ "Coming Up"
  end

  test "renders weather widget when weather is available", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    # WeatherClientStub returns temp 12.5 for "Victoria, BC"; the UI rounds to nearest integer (13°)
    assert html =~ "13"
    assert html =~ "Victoria"
  end

  test "shows a seed in Plant Now when its window is open and it is not planted", %{conn: conn} do
    seed_fixture(%{name: "April Spinach", ideal_planting_time: "spring"})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "April Spinach"
  end

  test "does not show a planted seed in Plant Now", %{conn: conn, user: user} do
    seed = seed_fixture(%{name: "Already Planted", ideal_planting_time: "spring"})
    planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/")

    # "Already Planted" should not appear in Plant Now (it will appear in Recently Planted)
    # Count occurrences — it should appear at most once (in recently planted), not twice
    count = html |> String.split("Already Planted") |> length() |> Kernel.-(1)
    assert count <= 1
  end

  test "shows a recently planted item in Recently Planted", %{conn: conn, user: user} do
    seed = seed_fixture(%{name: "Recent Basil"})
    planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Recent Basil"
  end

  test "shows upcoming seeds in Coming Up", %{conn: conn} do
    # May window will show as upcoming in April
    seed_fixture(%{name: "May Beans", ideal_planting_time: "may"})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "May Beans"
  end

  test "shows frost warning banner when forecast has sub-zero temperatures", %{
    conn: conn,
    user: user
  } do
    # WeatherClientStub returns sub-zero forecast for "FrostCity"
    original = Application.get_env(:backyard_garden, :default_location)
    Application.put_env(:backyard_garden, :default_location, "FrostCity")
    on_exit(fn -> Application.put_env(:backyard_garden, :default_location, original) end)

    # has_planted must be true for frost warning to appear
    seed = seed_fixture(%{name: "Frost Test Seed"})
    planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Frost"
  end

  test "expand_quick_log shows inline form for that seed", %{conn: conn} do
    seed = seed_fixture(%{name: "Quick Log Seed", type: "Herb", ideal_planting_time: "spring"})
    {:ok, view, _} = live(conn, ~p"/")
    html = render_click(view, "expand_quick_log", %{"id" => seed.id})
    assert html =~ "Save Planting"
    assert html =~ "Date planted"
  end

  test "save_quick_log creates a planting and removes seed from Plant Now", %{conn: conn} do
    seed = seed_fixture(%{name: "Log It Now", type: "Herb", ideal_planting_time: "spring"})

    {:ok, view, _html} = live(conn, ~p"/")
    render_click(view, "expand_quick_log", %{"id" => seed.id})

    html =
      view
      |> form("[id^=quick-log-form]", %{
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

    # Seed moves to Recently Planted, no longer in the Plant Now list
    assert html =~ "Planting logged!"
    assert html =~ "No seeds are in their ideal window right now."
  end
end
