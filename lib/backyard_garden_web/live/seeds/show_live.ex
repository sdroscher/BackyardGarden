defmodule BackyardGardenWeb.Seeds.ShowLive do
  @moduledoc """
  LiveView for displaying a single seed's details.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed_with_supplier!(id)
    {:ok, assign(socket, :seed, seed)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.seed.name)}
  end
end
