defmodule BackyardGardenWeb.HealthController do
  @moduledoc "Simple health check endpoint for Fly.io monitoring."
  use BackyardGardenWeb, :controller

  def index(conn, _params), do: send_resp(conn, 200, "ok")
end
