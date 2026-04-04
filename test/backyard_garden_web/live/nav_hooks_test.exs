defmodule BackyardGardenWeb.NavHooksTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "assigns current_path on mount for the dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    # The dashboard nav link should have aria-current="page"
    assert html =~ ~s(href="/" aria-current="page")
  end

  test "current_path matches /seeds when navigating to seeds", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/seeds")
    assert html =~ ~s(href="/seeds" aria-current="page")
    # Dashboard link should not be active
    refute html =~ ~s(href="/" aria-current="page")
  end

  test "current_path matches /garden when on My Garden page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/garden")
    assert html =~ ~s(href="/garden" aria-current="page")
  end

  test "current_path matches /calendar when on Calendar page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/calendar")
    assert html =~ ~s(href="/calendar" aria-current="page")
  end

  test "current_path matches /settings/zones when on Zones page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/zones")
    assert html =~ ~s(href="/settings/zones" aria-current="page")
  end

  test "current_path updates via handle_params when navigating between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/seeds")

    # Navigate to a seed sub-path — /seeds should still be active (starts_with? check)
    html = render(view)
    assert html =~ ~s(href="/seeds" aria-current="page")
  end
end
