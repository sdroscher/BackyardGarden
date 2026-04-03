defmodule BackyardGardenWeb.Settings.ZonesLive do
  @moduledoc """
  LiveView for managing garden zones — add, edit, and delete zones.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Garden Zones")
     |> assign(:zones, GardenZones.list_zones())
     |> assign(:editing_zone, nil)
     |> assign(:show_form, false)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_event("new_zone", _params, socket) do
    changeset = GardenZone.changeset(%GardenZone{}, %{})

    {:noreply,
     assign(socket, editing_zone: nil, show_form: true, form: to_form(changeset, as: "zone"))}
  end

  @impl true
  def handle_event("edit_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    changeset = GardenZone.changeset(zone, %{})

    {:noreply,
     assign(socket, editing_zone: zone, show_form: true, form: to_form(changeset, as: "zone"))}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, editing_zone: nil, show_form: false, form: nil)}
  end

  @impl true
  def handle_event("save_zone", %{"zone" => params}, socket) do
    result =
      case socket.assigns.editing_zone do
        nil -> GardenZones.create_zone(params)
        zone -> GardenZones.update_zone(zone, params)
      end

    case result do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> assign(:zones, GardenZones.list_zones())
         |> assign(:editing_zone, nil)
         |> assign(:show_form, false)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "zone"))}
    end
  end

  @impl true
  def handle_event("delete_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    {:ok, _} = GardenZones.delete_zone(zone)
    {:noreply, assign(socket, :zones, GardenZones.list_zones())}
  end
end
