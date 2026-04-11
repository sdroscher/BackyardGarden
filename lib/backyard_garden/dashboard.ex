defmodule BackyardGarden.Dashboard do
  @moduledoc "Query functions for the Dashboard page."

  import Ecto.Query

  alias BackyardGarden.{Repo, Seeds, PlantingCalendar}
  alias BackyardGarden.Plantings.Planting

  @doc """
  Seeds whose ideal planting window includes the month of `date`,
  excluding seeds that already have a "planted" or "planned" planting for this user.
  """
  def plant_now_seeds(user_id, date \\ Date.utc_today()) do
    active_ids = active_seed_ids(user_id)

    Seeds.list_seeds(user_id)
    |> Enum.reject(&(&1.id in active_ids))
    |> Enum.filter(&in_planting_window?(&1, date))
  end

  @doc "Returns the `limit` most recently planted plantings for a user with seed preloaded."
  def recently_planted(user_id, limit \\ 5) do
    Planting
    |> where([p], p.user_id == ^user_id and p.status == "planted")
    |> order_by([p], desc: fragment("coalesce(?, ?)", p.planted_at, p.inserted_at))
    |> limit(^limit)
    |> preload(:seed)
    |> Repo.all()
  end

  @doc """
  Seeds whose ideal planting window opens between 1 and `days_ahead` days after `date`,
  excluding seeds that already have a "planted" or "planned" planting for this user.
  Returns `[{seed, window_open_date}]` sorted by `window_open_date`.
  """
  def upcoming_schedule(user_id, date \\ Date.utc_today(), days_ahead \\ 60) do
    active_ids = active_seed_ids(user_id)

    Seeds.list_seeds(user_id)
    |> Enum.reject(&(&1.id in active_ids))
    |> Enum.flat_map(fn seed ->
      case upcoming_open_date(seed, date, days_ahead) do
        nil -> []
        open_date -> [{seed, open_date}]
      end
    end)
    |> Enum.sort_by(&elem(&1, 1), Date)
  end

  # --- private ---

  defp active_seed_ids(user_id) do
    Planting
    |> where([p], p.user_id == ^user_id and p.status in ["planted", "planned"])
    |> select([p], p.seed_id)
    |> Repo.all()
  end

  defp in_planting_window?(seed, %Date{month: month}) do
    seed.ideal_planting_time
    |> PlantingCalendar.parse_ideal_months()
    |> Enum.any?(fn {start_m, end_m} -> month_in_range?(month, start_m, end_m) end)
  end

  # Normal range: start_m <= end_m (e.g., March–May)
  defp month_in_range?(month, start_m, end_m) when start_m <= end_m do
    month >= start_m and month <= end_m
  end

  # Wrap-around range: start_m > end_m (e.g., Nov–Feb for winter)
  defp month_in_range?(month, start_m, end_m) do
    month >= start_m or month <= end_m
  end

  # Returns the earliest first-of-month across all planting windows that is
  # strictly after `from` and within `days_ahead`. Returns nil otherwise.
  defp upcoming_open_date(seed, from, days_ahead) do
    seed.ideal_planting_time
    |> PlantingCalendar.parse_ideal_months()
    |> Enum.map(fn {start_m, _end_m} -> next_month_first(from, start_m) end)
    |> Enum.filter(fn open_date ->
      days_until = Date.diff(open_date, from)
      days_until >= 1 and days_until <= days_ahead
    end)
    |> Enum.min(Date, fn -> nil end)
  end

  # Returns the 1st of `month` in the current year if that date is after `from`,
  # otherwise the 1st of `month` in the following year.
  defp next_month_first(%Date{year: year} = from, month) do
    candidate = Date.new!(year, month, 1)

    if Date.compare(candidate, from) == :gt do
      candidate
    else
      Date.new!(year + 1, month, 1)
    end
  end
end
