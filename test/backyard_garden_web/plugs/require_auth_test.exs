defmodule BackyardGardenWeb.Plugs.RequireAuthTest do
  use BackyardGardenWeb.ConnCase, async: false

  alias BackyardGardenWeb.Plugs.RequireAuth

  test "passes through if user_id is in session", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{user_id: "some-uuid"})
      |> RequireAuth.call([])

    refute conn.halted
  end

  test "redirects to Auth0 login if no user_id in session", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> RequireAuth.call([])

    assert conn.halted
    assert redirected_to(conn) == "/auth/auth0"
  end
end
