defmodule BackyardGardenWeb.AuthHooks do
  @moduledoc """
  LiveView on_mount hook that loads current_user from the session.
  Redirects to Auth0 login if no user is found.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias BackyardGarden.Users

  def on_mount(:default, _params, session, socket) do
    case session["user_id"] && Users.get_user(session["user_id"]) do
      nil ->
        {:halt, redirect(socket, to: "/auth/auth0")}

      user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end
end
