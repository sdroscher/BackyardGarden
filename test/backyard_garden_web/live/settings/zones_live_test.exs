defmodule BackyardGardenWeb.Settings.ZonesLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.GardenZones
  alias BackyardGarden.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp zone_fixture(user, attrs) do
    defaults = %{name: "Test Zone", sun_exposures: "full_sun", user_id: user.id}
    {:ok, zone} = GardenZones.create_zone(Map.merge(defaults, attrs))
    zone
  end

  test "renders Garden Zones heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "Garden Zones"
  end

  test "lists all zones", %{conn: conn, user: user} do
    zone_fixture(user, %{name: "My Zone"})
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "My Zone"
  end

  test "shows Add Zone button", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "Add Zone"
  end

  test "creates a new zone via the form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})
    render_click(view, "toggle_pill", %{"field" => "sun", "pill" => "full_sun"})

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => "Fruit Patch"}})
      |> render_submit()

    assert html =~ "Fruit Patch"
  end

  test "toggle_pill selects a sun value", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})
    render_click(view, "toggle_pill", %{"field" => "sun", "pill" => "full_sun"})

    assert view
           |> element("button[phx-value-field=sun][phx-value-pill=full_sun]")
           |> render() =~ "bg-[#2d6a4f]"
  end

  test "toggle_pill deselects a value when clicked again", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})
    render_click(view, "toggle_pill", %{"field" => "sun", "pill" => "full_sun"})
    render_click(view, "toggle_pill", %{"field" => "sun", "pill" => "full_sun"})

    assert view
           |> element("button[phx-value-field=sun][phx-value-pill=any]")
           |> render() =~ "bg-[#6b7280]"
  end

  test "toggle_pill 'any' clears specific selections", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})
    render_click(view, "toggle_pill", %{"field" => "type", "pill" => "Vegetable"})
    render_click(view, "toggle_pill", %{"field" => "type", "pill" => "any"})

    assert view
           |> element("button[phx-value-field=type][phx-value-pill=any]")
           |> render() =~ "bg-[#6b7280]"
  end

  test "creates a zone with pill-selected sun exposure", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})
    render_click(view, "toggle_pill", %{"field" => "sun", "pill" => "partial_sun"})

    view
    |> form("#zone-form", %{"zone" => %{"name" => "Shady Corner"}})
    |> render_submit()

    assert GardenZones.list_zones(user.id)
           |> Enum.any?(&(&1.sun_exposures == "partial_sun"))
  end

  test "deletes a zone", %{conn: conn, user: user} do
    zone = zone_fixture(user, %{name: "Delete Me"})
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    html = render_click(view, "delete_zone", %{"id" => zone.id})
    refute html =~ "Delete Me"
  end

  test "edits a zone", %{conn: conn, user: user} do
    zone = zone_fixture(user, %{name: "Old Name"})
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "edit_zone", %{"id" => zone.id})

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => "New Name"}})
      |> render_submit()

    assert html =~ "New Name"
    refute html =~ "Old Name"
  end

  test "shows validation error when saving zone with blank name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    render_click(view, "new_zone", %{})

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => ""}})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end
end
