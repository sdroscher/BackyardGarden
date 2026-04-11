defmodule BackyardGardenWeb.Calendar.IndexLive do
  @moduledoc """
  LiveView for the planting calendar — month grid with planted, harvest-due,
  and ideal-window markers.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.PlantingCalendar
  alias BackyardGarden.Plantings
  alias BackyardGarden.Seeds

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    current_month = %{today | day: 1}
    {:ok, socket |> assign(:current_month, current_month) |> load_calendar_data()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Planting Calendar")}
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    new_month =
      socket.assigns.current_month
      |> Date.add(-1)
      |> then(&%{&1 | day: 1})

    {:noreply, socket |> assign(:current_month, new_month) |> load_calendar_data()}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_month =
      socket.assigns.current_month
      |> Date.end_of_month()
      |> Date.add(1)

    {:noreply, socket |> assign(:current_month, new_month) |> load_calendar_data()}
  end

  defp load_calendar_data(socket) do
    month = socket.assigns.current_month
    {first_day, _last_day} = PlantingCalendar.month_range(month)
    weeks = PlantingCalendar.weeks_for_month(first_day)
    plantings = Plantings.list_plantings_for_month(socket.assigns.current_user.id, first_day)

    events_by_date =
      Enum.reduce(plantings, %{}, fn planting, acc ->
        name = planting.seed.name

        acc
        |> maybe_add_event(planting.planted_at, {:planted, name})
        |> maybe_add_event(harvest_date(planting), {:harvest_due, name})
      end)

    ideal_seeds =
      Seeds.list_seeds(socket.assigns.current_user.id)
      |> Enum.filter(fn seed ->
        seed.ideal_planting_time
        |> PlantingCalendar.parse_ideal_months()
        |> Enum.any?(fn {start_m, _end_m} -> start_m == month.month end)
      end)
      |> Enum.map(& &1.name)

    socket
    |> assign(:weeks, weeks)
    |> assign(:events_by_date, events_by_date)
    |> assign(:ideal_seeds, ideal_seeds)
    |> assign(:today, Date.utc_today())
    |> assign(:month_label, Calendar.strftime(month, "%B %Y"))
  end

  defp maybe_add_event(acc, nil, _type), do: acc

  defp maybe_add_event(acc, date, type) do
    Map.update(acc, date, [type], fn existing -> [type | existing] end)
  end

  defp harvest_date(%{planted_at: nil}), do: nil
  defp harvest_date(%{seed: %{maturity_days: nil}}), do: nil
  defp harvest_date(%{seed: %{maturity_days: 0}}), do: nil

  defp harvest_date(%{planted_at: planted_at, seed: %{maturity_days: days}}) do
    Date.add(planted_at, days)
  end
end
