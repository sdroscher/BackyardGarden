defmodule BackyardGardenWeb.Seeds.IndexLive do
  use BackyardGardenWeb, :live_view

  @moduledoc """
  LiveView for browsing and filtering the seed library.
  """

  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_filters(%{})
     |> assign(:types, Seeds.list_types())
     |> assign(:brands, Seeds.list_brands())
     |> assign(:cycles, Seeds.list_cycles())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      type: params["type"] || "",
      brand: params["brand"] || "",
      cycle: params["cycle"] || "",
      search: params["search"] || ""
    }

    {:noreply, assign_filters(socket, filters)}
  end

  defp assign_filters(socket, filters) do
    seeds = Seeds.list_seeds(filters)

    socket
    |> assign(:seeds, seeds)
    |> assign(:seed_count, length(seeds))
    |> assign(:filters, filters)
  end
end
