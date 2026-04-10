defmodule BackyardGardenWeb.AuthController do
  @moduledoc "Handles Ueberauth OAuth callbacks and logout."

  use BackyardGardenWeb, :controller

  plug Ueberauth

  alias BackyardGarden.Users

  # Ueberauth intercepts /auth/auth0 and redirects to Auth0 before this action
  # is reached — it exists to satisfy Phoenix's route dispatch requirement.
  def request(conn, _params), do: conn

  # Triggered by Ueberauth after successful Auth0 authentication.
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Users.upsert_from_auth0(auth) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome, #{user.name || user.email}!")
        |> redirect(to: ~p"/")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed. Please try again.")
    |> redirect(to: ~p"/")
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/")
  end
end
