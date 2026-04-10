defmodule BackyardGardenWeb.AuthControllerTest do
  use BackyardGardenWeb.ConnCase, async: false

  alias BackyardGarden.Users

  describe "request/2" do
    test "redirects to Auth0 authorize URL", %{conn: conn} do
      conn = get(conn, ~p"/auth/auth0")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> List.first()
      assert location =~ "authorize"
    end
  end

  describe "callback/2 with successful Auth0 response" do
    test "creates user, stores user_id in session, redirects to /", %{conn: conn} do
      ueberauth_auth = %Ueberauth.Auth{
        uid: "auth0|test123",
        info: %Ueberauth.Auth.Info{email: "test@example.com", name: "Test User"},
        provider: :auth0
      }

      conn =
        conn
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> get(~p"/auth/auth0/callback")

      user = Users.get_user_by_email("test@example.com")
      assert user != nil
      assert get_session(conn, :user_id) == user.id
      assert redirected_to(conn) == "/"
    end
  end

  # When the callback is hit without a valid OAuth state (e.g. no code+state params),
  # ueberauth itself sets ueberauth_failure with a CSRF error. These tests hit the
  # real ueberauth plug path to verify our callback handler doesn't cause a redirect loop.
  describe "callback/2 with Auth0 failure" do
    test "redirects to /auth/auth0, not to a protected page", %{conn: conn} do
      # Hit callback without a valid code/state — ueberauth will set ueberauth_failure.
      conn = get(conn, ~p"/auth/auth0/callback")
      assert redirected_to(conn) == "/auth/auth0"
    end

    test "sets an error flash with the failure reason", %{conn: conn} do
      conn = get(conn, ~p"/auth/auth0/callback")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Sign in failed"
    end
  end

  describe "callback/2 with upsert failure" do
    # plug Ueberauth rewrites conn.assigns during HTTP dispatch, so we call the
    # action directly to test the {:error, changeset} branch in isolation.
    test "returns 500 and does not redirect to a protected page", %{conn: conn} do
      # A nil email fails the User changeset validation, so upsert returns {:error, ...}.
      ueberauth_auth = %Ueberauth.Auth{
        uid: "auth0|newuser",
        info: %Ueberauth.Auth.Info{email: nil, name: "No Email"},
        provider: :auth0
      }

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> BackyardGardenWeb.AuthController.callback(%{})

      assert conn.status == 500
      assert get_resp_header(conn, "location") == []
    end
  end

  describe "delete/2" do
    test "clears session and redirects to /auth/auth0", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: "some-user-id"})
        |> delete(~p"/auth/logout")

      assert get_session(conn, :user_id) == nil
      assert redirected_to(conn) == "/auth/auth0"
    end
  end
end
