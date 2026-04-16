defmodule BackyardGardenWeb.Settings.ZonesLive do
  @moduledoc """
  LiveView for managing garden zones — add, edit, and delete zones.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone

  @sun_options [
    {"Full Sun", "full_sun"},
    {"Partial Sun", "partial_sun"},
    {"Shade Tolerant", "shade_tolerant"}
  ]
  @type_options ["Vegetable", "Herb", "Flower", "Berry"]
  @cycle_options ["Annual", "Biennial", "Perennial"]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     socket
     |> assign(:page_title, "Garden Zones")
     |> assign(:zones, GardenZones.list_zones(user_id))
     |> assign(:editing_zone, nil)
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> assign(:sun_options, @sun_options)
     |> assign(:type_options, @type_options)
     |> assign(:cycle_options, @cycle_options)
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("new_zone", _params, socket) do
    changeset = GardenZone.changeset(%GardenZone{}, %{})

    {:noreply,
     socket
     |> assign(editing_zone: nil, show_form: true, form: to_form(changeset, as: "zone"))
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("edit_zone", %{"id" => id}, socket) do
    zone = GardenZones.get_zone!(id)
    changeset = GardenZone.changeset(zone, %{})

    {:noreply,
     socket
     |> assign(editing_zone: zone, show_form: true, form: to_form(changeset, as: "zone"))
     |> assign(:sun_selections, parse_selections(zone.sun_exposures))
     |> assign(:type_selections, parse_selections(zone.allowed_types))
     |> assign(:cycle_selections, parse_selections(zone.allowed_cycles))}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(editing_zone: nil, show_form: false, form: nil)
     |> assign_empty_selections()}
  end

  @impl true
  def handle_event("toggle_pill", %{"field" => field, "pill" => value}, socket) do
    key = selections_key(field)
    current = Map.get(socket.assigns, key)

    new_selections =
      cond do
        value == "any" -> MapSet.new()
        MapSet.member?(current, value) -> MapSet.delete(current, value)
        true -> MapSet.put(current, value)
      end

    require Logger

    Logger.info(
      "toggle_pill field=#{field} value=#{value} before=#{inspect(current)} after=#{inspect(new_selections)}"
    )

    {:noreply, assign(socket, key, new_selections)}
  end

  @impl true
  def handle_event("save_zone", %{"zone" => params}, socket) do
    user_id = socket.assigns.current_user.id

    params =
      params
      |> Map.put("sun_exposures", join_selections(socket.assigns.sun_selections))
      |> Map.put("allowed_types", join_selections(socket.assigns.type_selections))
      |> Map.put("allowed_cycles", join_selections(socket.assigns.cycle_selections))
      |> Map.put("user_id", user_id)

    result =
      case socket.assigns.editing_zone do
        nil -> GardenZones.create_zone(params)
        zone -> GardenZones.update_zone(zone, params)
      end

    case result do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> assign(:zones, GardenZones.list_zones(user_id))
         |> assign(:editing_zone, nil)
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> assign_empty_selections()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "zone"))}
    end
  end

  @impl true
  def handle_event("validate_zone", %{"zone" => params}, socket) do
    changeset =
      case socket.assigns.editing_zone do
        nil -> GardenZone.changeset(%GardenZone{}, params)
        zone -> GardenZone.changeset(zone, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "zone"))}
  end

  @impl true
  def handle_event("delete_zone", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    zone = GardenZones.get_zone!(id)

    case GardenZones.delete_zone(zone) do
      {:ok, _} ->
        {:noreply, assign(socket, :zones, GardenZones.list_zones(user_id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete zone.")}
    end
  end

  defp assign_empty_selections(socket) do
    socket
    |> assign(:sun_selections, MapSet.new())
    |> assign(:type_selections, MapSet.new())
    |> assign(:cycle_selections, MapSet.new())
  end

  defp parse_selections(nil), do: MapSet.new()
  defp parse_selections(""), do: MapSet.new()
  defp parse_selections(str), do: str |> String.split(",", trim: true) |> MapSet.new()

  defp join_selections(set), do: set |> MapSet.to_list() |> Enum.join(",")

  defp selections_key("sun"), do: :sun_selections
  defp selections_key("type"), do: :type_selections
  defp selections_key("cycle"), do: :cycle_selections

  defp format_sun(value) do
    value
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
