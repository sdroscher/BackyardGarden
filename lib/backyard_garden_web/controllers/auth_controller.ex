defmodule BackyardGardenWeb.AuthController do
  @moduledoc "Handles Ueberauth OAuth callbacks and logout."

  use BackyardGardenWeb, :controller

  require Logger

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

      {:error, changeset} ->
        Logger.error("Auth0 callback: failed to upsert user — #{inspect(changeset.errors)}")

        conn
        |> put_status(:internal_server_error)
        |> text("Could not create your account. Check the server logs for details.")
    end
  end

  # Ueberauth signals an auth failure (e.g. state mismatch, token exchange error).
  # Redirecting to "/" here would loop: "/" requires auth → /auth/auth0 → Auth0 → callback → repeat.
  # Instead, log the reason and redirect to the login entry point for a fresh attempt.
  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    reasons = Enum.map_join(failure.errors, ", ", & &1.message)
    Logger.error("Auth0 callback failure: #{reasons}")

    conn
    |> put_flash(:error, "Sign in failed (#{reasons}). Please try again.")
    |> redirect(to: ~p"/auth/auth0")
  end

  def delete(conn, _params) do
    %{domain: domain, client_id: client_id} =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)
      |> Map.new()

    return_to = url(~p"/auth/auth0")

    logout_url =
      "https://#{domain}/v2/logout?client_id=#{client_id}&returnTo=#{URI.encode_www_form(return_to)}"

    conn
    |> clear_session()
    |> redirect(external: logout_url)
  end
end
