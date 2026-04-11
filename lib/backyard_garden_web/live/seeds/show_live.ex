defmodule BackyardGardenWeb.Seeds.ShowLive do
  @moduledoc """
  LiveView for displaying a single seed's details.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.{Seeds, Plantings, GardenZones}
  alias BackyardGarden.PlantingCalendar

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed_with_supplier!(id)

    if seed.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "Seed not found.")
       |> push_navigate(to: ~p"/seeds")}
    else
      status = season_status(seed)
      zones = GardenZones.recommend_zones(socket.assigns.current_user.id, seed)

      {:ok,
       socket
       |> assign(:seed, seed)
       |> assign(:season_status, status)
       |> assign(:show_log_form, false)
       |> assign(:log_form, nil)
       |> assign(:log_zones, zones)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.seed.name)}
  end

  @impl true
  def handle_event("show_log_form", _params, socket) do
    seed = socket.assigns.seed

    form =
      %Plantings.Planting{}
      |> Plantings.change_planting(%{
        seed_id: seed.id,
        planted_at: Date.utc_today(),
        status: "planted"
      })
      |> to_form(as: "planting")

    {:noreply, socket |> assign(:show_log_form, true) |> assign(:log_form, form)}
  end

  @impl true
  def handle_event("hide_log_form", _params, socket) do
    {:noreply, socket |> assign(:show_log_form, false) |> assign(:log_form, nil)}
  end

  @impl true
  def handle_event("validate_planting", %{"planting" => params}, socket) do
    form =
      %Plantings.Planting{}
      |> Plantings.change_planting(normalise_params(params))
      |> Map.put(:action, :validate)
      |> to_form(as: "planting")

    {:noreply, assign(socket, :log_form, form)}
  end

  @impl true
  def handle_event("save_planting", %{"planting" => params}, socket) do
    params = params |> normalise_params() |> Map.put("user_id", socket.assigns.current_user.id)

    case Plantings.create_planting(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_log_form, false)
         |> assign(:log_form, nil)
         |> put_flash(:info, "Planting logged!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :log_form, to_form(changeset, as: "planting"))}
    end
  end

  defp normalise_params(params) do
    params
    |> Map.update("zone_id", nil, fn v -> if v == "", do: nil, else: v end)
    |> Map.update("planted_at", nil, fn v ->
      case Date.from_iso8601(v) do
        {:ok, d} -> d
        _ -> nil
      end
    end)
  end

  defp season_status(seed) do
    m = Date.utc_today().month

    in_window =
      seed.ideal_planting_time
      |> PlantingCalendar.parse_ideal_months()
      |> Enum.any?(fn {start_m, end_m} ->
        if start_m <= end_m, do: m >= start_m and m <= end_m, else: m >= start_m or m <= end_m
      end)

    if in_window, do: :in_season, else: :out_of_season
  end
end
