defmodule BackyardGardenWeb.Plugs.RequireAuth do
  @moduledoc "Redirects unauthenticated requests to the Auth0 login flow."

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :user_id) do
      conn
    else
      conn
      |> redirect(to: "/auth/auth0")
      |> halt()
    end
  end
end
