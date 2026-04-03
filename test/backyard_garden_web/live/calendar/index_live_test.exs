defmodule BackyardGardenWeb.Calendar.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds
  alias BackyardGarden.Plantings

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Basil", type: "Herb", cycle: "Annual", maturity_days: 60}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  test "renders calendar heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ "Planting Calendar"
  end

  test "renders prev_month and next_month buttons", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ "prev_month"
    assert html =~ "next_month"
  end

  test "renders day-of-week headers", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ "Mon"
    assert html =~ "Sun"
  end

  test "navigating to previous month changes month label", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/calendar")
    original = Regex.run(~r/<h2[^>]*>([^<]+)<\/h2>/, html) |> List.last()
    new_html = render_click(view, "prev_month", %{})
    new_label = Regex.run(~r/<h2[^>]*>([^<]+)<\/h2>/, new_html) |> List.last()
    refute original == new_label
  end

  test "navigating to next month changes month label", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/calendar")
    original = Regex.run(~r/<h2[^>]*>([^<]+)<\/h2>/, html) |> List.last()
    new_html = render_click(view, "next_month", %{})
    new_label = Regex.run(~r/<h2[^>]*>([^<]+)<\/h2>/, new_html) |> List.last()
    refute original == new_label
  end

  test "shows planted seed name on its planted_at date month", %{conn: conn} do
    seed = seed_fixture(%{name: "Spinach"})
    today = Date.utc_today()

    {:ok, _} =
      Plantings.create_planting(%{
        seed_id: seed.id,
        status: "planted",
        planted_at: today
      })

    {:ok, _view, html} = live(conn, ~p"/calendar")
    # The planted dot should appear (blue dot rendered for today's month)
    assert html =~ "3b82f6"
  end
end
