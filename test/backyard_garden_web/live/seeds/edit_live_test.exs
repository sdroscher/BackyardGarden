defmodule BackyardGardenWeb.Seeds.EditLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.Seeds

  setup do
    {:ok, seed} =
      Seeds.create_seed(%{
        name: "Basil",
        brand: "Metchosin Farm",
        type: "Herb",
        cycle: "Annual",
        maturity_days: 60
      })

    %{seed: seed}
  end

  test "renders edit form with seed fields pre-filled", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}/edit")
    assert html =~ "Basil"
    assert html =~ "Metchosin Farm"
    assert html =~ "Edit Seed"
  end

  test "updates seed and redirects to show page", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}/edit")

    {:ok, _show_view, html} =
      view
      |> form("#seed-edit-form", %{
        "seed" => %{"sun_requirement" => "full_sun", "source_url" => "https://example.com"}
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/seeds/#{seed.id}")

    assert html =~ "Full sun"
  end

  test "shows validation error when name is cleared", %{conn: conn, seed: seed} do
    {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}/edit")

    html =
      view
      |> form("#seed-edit-form", %{"seed" => %{"name" => ""}})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end

  test "back link navigates to show page", %{conn: conn, seed: seed} do
    {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}/edit")
    assert html =~ ~p"/seeds/#{seed.id}"
  end
end
