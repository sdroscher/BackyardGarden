defmodule BackyardGardenWeb.Settings.ZonesLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.GardenZones
  alias BackyardGarden.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp zone_fixture(attrs) do
    defaults = %{name: "Test Zone", sun_exposures: "full_sun"}
    {:ok, zone} = GardenZones.create_zone(Map.merge(defaults, attrs))
    zone
  end

  test "renders Garden Zones heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ "Garden Zones"
  end

  test "lists all zones", %{conn: conn} do
    zone_fixture(%{name: "My Zone"})
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

    html =
      view
      |> form("#zone-form", %{"zone" => %{"name" => "Fruit Patch", "sun_exposures" => "full_sun"}})
      |> render_submit()

    assert html =~ "Fruit Patch"
  end

  test "deletes a zone", %{conn: conn} do
    zone = zone_fixture(%{name: "Delete Me"})
    {:ok, view, _html} = live(conn, ~p"/settings/zones")
    html = render_click(view, "delete_zone", %{"id" => zone.id})
    refute html =~ "Delete Me"
  end

  test "edits a zone", %{conn: conn} do
    zone = zone_fixture(%{name: "Old Name"})
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
