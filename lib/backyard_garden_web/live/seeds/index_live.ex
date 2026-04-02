defmodule BackyardGardenWeb.Seeds.IndexLive do
  @moduledoc """
  LiveView for browsing, filtering, and sorting the seed library.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sort_field, nil)
     |> assign(:sort_dir, :asc)
     |> assign_filters(%{})
     |> assign(:types, Seeds.list_types())
     |> assign(:brands, Seeds.list_brands())
     |> assign(:cycles, Seeds.list_cycles())
     |> assign(:planting_methods, Seeds.list_planting_methods())
     |> assign(:sun_requirements, Seeds.list_sun_requirements())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      type: params["type"] || "",
      brand: params["brand"] || "",
      cycle: params["cycle"] || "",
      planting_method: params["planting_method"] || "",
      sun_requirement: params["sun_requirement"] || "",
      search: params["search"] || ""
    }

    {:noreply, assign_filters(socket, filters)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    new_dir =
      if field == socket.assigns.sort_field do
        if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
      else
        :asc
      end

    {:noreply,
     socket
     |> assign(:sort_field, field)
     |> assign(:sort_dir, new_dir)
     |> assign_filters(socket.assigns.filters)}
  end

  defp assign_filters(socket, filters) do
    seeds =
      Seeds.list_seeds(
        Map.merge(filters, %{
          sort_field: socket.assigns.sort_field,
          sort_dir: socket.assigns.sort_dir
        })
      )

    socket
    |> assign(:seeds, seeds)
    |> assign(:seed_count, length(seeds))
    |> assign(:filters, filters)
  end

  defp sort_indicator(sort_field, sort_dir, field) do
    cond do
      sort_field == field and sort_dir == :asc -> "↑"
      sort_field == field -> "↓"
      true -> "↕"
    end
  end

  defp mobile_card_border("Vegetable"), do: "border-t-[3px] border-t-[#16a34a]"
  defp mobile_card_border("Herb"), do: "border-t-[3px] border-t-[#7c3aed]"
  defp mobile_card_border("Flower"), do: "border-t-[3px] border-t-[#d97706]"
  defp mobile_card_border(_), do: "border-t-[3px] border-t-[#db2777]"
end
