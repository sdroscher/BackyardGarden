defmodule BackyardGardenWeb.PageController do
  use BackyardGardenWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
