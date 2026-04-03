defmodule BackyardGardenWeb.Garden.IndexLive do
  @moduledoc """
  LiveView for the My Garden page — lists plantings grouped by status
  and provides a form to log new plantings.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.GardenZones
  alias BackyardGarden.Plantings
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Garden")
     |> assign(:seeds, Seeds.list_seeds())
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> assign(:recommended_zones, [])
     |> load_plantings()}
  end

  @impl true
  def handle_event("mark_planted", %{"id" => id}, socket) do
    planting = Plantings.get_planting!(id)
    today = Date.utc_today()

    {:ok, _} =
      Plantings.update_planting(planting, %{
        status: "planted",
        planted_at: planting.planted_at || today
      })

    {:noreply, load_plantings(socket)}
  end

  @impl true
  def handle_event("mark_harvested", %{"id" => id}, socket) do
    planting = Plantings.get_planting!(id)

    {:ok, _} =
      Plantings.update_planting(planting, %{status: "harvested", harvested_at: Date.utc_today()})

    {:noreply, load_plantings(socket)}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    changeset = Plantings.change_planting(%Planting{})

    {:noreply,
     assign(socket,
       show_form: true,
       form: to_form(changeset),
       recommended_zones: []
     )}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form: nil, recommended_zones: [])}
  end

  @impl true
  def handle_event("validate_planting", %{"planting" => %{"seed_id" => seed_id} = params}, socket) do
    changeset =
      %Planting{}
      |> Plantings.change_planting(params)
      |> Map.put(:action, :validate)

    recommended_zones =
      case Seeds.get_seed(seed_id) do
        nil -> []
        seed -> GardenZones.recommend_zones(seed)
      end

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:recommended_zones, recommended_zones)}
  end

  @impl true
  def handle_event("save_planting", %{"planting" => params}, socket) do
    case Plantings.create_planting(params) do
      {:ok, _planting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planting logged successfully.")
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> assign(:recommended_zones, [])
         |> load_plantings()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp load_plantings(socket) do
    socket
    |> assign(:planted, Plantings.list_plantings_by_status("planted"))
    |> assign(:planned, Plantings.list_plantings_by_status("planned"))
    |> assign(:harvested, Plantings.list_plantings_by_status("harvested"))
  end

  defp estimated_harvest(%{planted_at: nil}), do: nil
  defp estimated_harvest(%{seed: %{maturity_days: nil}}), do: nil
  defp estimated_harvest(%{seed: %{maturity_days: 0}}), do: nil

  defp estimated_harvest(%{planted_at: planted_at, seed: %{maturity_days: days}}) do
    Date.add(planted_at, days)
  end
end
