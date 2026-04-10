defmodule BackyardGardenWeb.AuthControllerTest do
  use BackyardGardenWeb.ConnCase, async: false

  alias BackyardGarden.Users

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

  describe "callback/2 with Auth0 failure" do
    test "redirects to / with error flash", %{conn: conn} do
      conn =
        conn
        |> assign(:ueberauth_failure, %Ueberauth.Failure{
          provider: :auth0,
          errors: [%Ueberauth.Failure.Error{message: "access_denied"}]
        })
        |> get(~p"/auth/auth0/callback")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end
  end

  describe "delete/2" do
    test "clears session and redirects to /", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: "some-user-id"})
        |> delete(~p"/auth/logout")

      assert get_session(conn, :user_id) == nil
      assert redirected_to(conn) == "/"
    end
  end
end
