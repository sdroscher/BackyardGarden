defmodule BackyardGarden.Workers.HourlyCheckWorker do
  @moduledoc """
  Hourly scheduled job that dispatches morning and evening notification checks
  for each user at their configured reminder times.

  Replaces DailyCheckWorker. Runs at the top of every hour via Oban cron.
  Morning checks: sow_now, start_hardening, hardening weather warning,
  hardening_morning, plant_now, harvest_soon.
  Evening checks: hardening_evening.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  import Ecto.Query

  alias BackyardGarden.{Repo, Users, Dashboard, Notifications}
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Notifications.Notification
  alias BackyardGarden.Weather

  @rain_conditions ~w(Rain Drizzle Thunderstorm)
  @wind_threshold_kmh 40
  @heat_threshold_c 30

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("HourlyCheckWorker: running hourly notification check")

    users_with_prowl =
      Users.list_users()
      |> Enum.filter(&(&1.notifications_enabled and &1.prowl_api_key))

    Enum.each(users_with_prowl, &check_user/1)

    :ok
  end

  defp check_user(user) do
    current_hour = current_hour_for_user(user)

    if current_hour == user.morning_reminder_hour do
      Logger.info("HourlyCheckWorker: running morning checks for user #{user.id}")
      run_morning_checks(user)
    end

    if current_hour == user.evening_reminder_hour do
      Logger.info("HourlyCheckWorker: running evening checks for user #{user.id}")
      run_evening_checks(user)
    end
  end

  defp run_morning_checks(user) do
    today = Date.utc_today()

    check_sow_now(user, today)
    check_start_hardening(user, today)

    # Weather warning takes priority over the morning take-outside reminder
    warned = check_hardening_weather_warning(user)
    unless warned, do: check_hardening_morning(user)

    check_plant_now(user, today)
    check_harvest_soon(user, today)
  end

  defp run_evening_checks(user) do
    check_hardening_evening(user)
  end

  # --- Seedling checks ---

  defp check_sow_now(user, today) do
    # Find planned seedling plantings where the calculated sow date is today
    seedling_plantings_for_user(user, "planned")
    |> Enum.each(fn planting ->
      sow = BackyardGarden.Plantings.sow_date(planting)

      if sow && Date.compare(sow, today) == :eq &&
           not recently_notified_planting?(user.id, planting.id, "sow_now") do
        message =
          "Time to sow your #{planting.seed.name} indoors — target transplant is #{planting.planted_at}"

        notify_planting(user, planting, "sow_now", message)
      end
    end)
  end

  defp check_start_hardening(user, today) do
    # Find sown seedling plantings where the hardening start date is today
    seedling_plantings_for_user(user, "sown")
    |> Enum.each(&maybe_notify_start_hardening(user, &1, today))
  end

  defp maybe_notify_start_hardening(user, planting, today) do
    harden_start = BackyardGarden.Plantings.hardening_start_date(planting)

    if harden_start && Date.compare(harden_start, today) == :eq &&
         not recently_notified_planting?(user.id, planting.id, "start_hardening") do
      transplant = BackyardGarden.Plantings.projected_transplant_date(planting)

      message =
        "Time to start hardening your #{planting.seed.name}" <>
          if(transplant, do: " — transplant in #{Date.diff(transplant, today)} days", else: "")

      notify_planting(user, planting, "start_hardening", message)
    end
  end

  # Returns true if a warning was sent (so caller can skip the regular morning reminder)
  defp check_hardening_weather_warning(user) do
    hardening = seedling_plantings_for_user(user, "hardening")

    with false <- hardening == [],
         config = Application.get_env(:backyard_garden, :weather, []),
         location when not is_nil(location) <- Keyword.get(config, :default_location),
         {:ok, weather} <- Weather.get_weather(location),
         reason when not is_nil(reason) <- bad_weather_reason(weather) do
      Enum.each(hardening, &maybe_warn_hardening_weather(user, &1, reason))

      true
    else
      _ -> false
    end
  end

  defp check_hardening_morning(user) do
    seedling_plantings_for_user(user, "hardening")
    |> Enum.each(fn planting ->
      unless recently_notified_planting?(user.id, planting.id, "hardening_morning") do
        message = "Time to take your #{planting.seed.name} outside for today's hardening"
        notify_planting(user, planting, "hardening_morning", message)
      end
    end)
  end

  defp check_hardening_evening(user) do
    seedling_plantings_for_user(user, "hardening")
    |> Enum.each(fn planting ->
      unless recently_notified_planting?(user.id, planting.id, "hardening_evening") do
        message = "Time to bring your #{planting.seed.name} inside for the night"
        notify_planting(user, planting, "hardening_evening", message)
      end
    end)
  end

  # --- Existing checks (unchanged logic, moved from DailyCheckWorker) ---

  defp check_plant_now(user, date) do
    Dashboard.plant_now_seeds(date)
    |> Enum.each(fn seed ->
      unless recently_notified?(user.id, seed.id, nil, "plant_now") do
        message = "#{seed.name} is ready to plant! Ideal window is open now."

        {:ok, notification} =
          Notifications.log_notification(%{
            "user_id" => user.id,
            "seed_id" => seed.id,
            "type" => "plant_now",
            "message" => message,
            "scheduled_at" => DateTime.utc_now()
          })

        enqueue_prowl_job(notification.id)
      end
    end)
  end

  defp check_harvest_soon(user, date) do
    Planting
    |> where([p], p.user_id == ^user.id and p.status == "planted")
    |> Repo.all()
    |> Enum.filter(&harvest_window_open?(&1, date))
    |> Enum.each(fn planting ->
      unless recently_notified?(user.id, nil, planting.id, "harvest_soon") do
        seed = Repo.preload(planting, :seed).seed
        message = "#{seed.name} is nearly ready to harvest!"

        {:ok, notification} =
          Notifications.log_notification(%{
            "user_id" => user.id,
            "planting_id" => planting.id,
            "type" => "harvest_soon",
            "message" => message,
            "scheduled_at" => DateTime.utc_now()
          })

        enqueue_prowl_job(notification.id)
      end
    end)
  end

  # --- Helpers ---

  defp maybe_warn_hardening_weather(user, planting, reason) do
    unless recently_notified_planting?(user.id, planting.id, "hardening_weather_warning") do
      message = "Keep your #{planting.seed.name} inside today — #{reason}"
      notify_planting(user, planting, "hardening_weather_warning", message)
    end
  end

  defp seedling_plantings_for_user(user, status) do
    Planting
    |> where([p], p.user_id == ^user.id and p.status == ^status)
    |> Repo.all()
    |> Repo.preload(:seed)
    |> Enum.filter(fn p ->
      p.seed.planting_method == "Seedlings" &&
        p.seed.weeks_to_start_indoors != nil &&
        p.seed.hardening_days != nil
    end)
  end

  defp notify_planting(user, planting, type, message) do
    {:ok, notification} =
      Notifications.log_notification(%{
        "user_id" => user.id,
        "planting_id" => planting.id,
        "type" => type,
        "message" => message,
        "scheduled_at" => DateTime.utc_now()
      })

    enqueue_prowl_job(notification.id)
  end

  defp bad_weather_reason(%{condition: condition, wind_speed_kmh: wind, temp: temp}) do
    cond do
      condition in @rain_conditions -> "#{condition |> String.downcase()} expected"
      wind >= @wind_threshold_kmh -> "high wind expected (#{round(wind)} km/h)"
      temp >= @heat_threshold_c -> "heat expected (#{round(temp)}°C)"
      true -> nil
    end
  end

  defp harvest_window_open?(%Planting{planted_at: nil}, _date), do: false

  defp harvest_window_open?(planting, date) do
    seed = Repo.preload(planting, :seed).seed
    days_since_planted = Date.diff(date, planting.planted_at)
    days_until_mature = seed.maturity_days - days_since_planted
    days_until_mature >= 0 and days_until_mature <= 7
  end

  defp recently_notified_planting?(user_id, planting_id, type) do
    recently_notified?(user_id, nil, planting_id, type)
  end

  defp recently_notified?(user_id, seed_id, planting_id, type) do
    days_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    query =
      Notification
      |> where([n], n.user_id == ^user_id and n.type == ^type)
      |> where([n], n.inserted_at > ^days_ago)

    query =
      if seed_id,
        do: where(query, [n], n.seed_id == ^seed_id),
        else: where(query, [n], n.planting_id == ^planting_id)

    Repo.exists?(query)
  end

  defp current_hour_for_user(user) do
    timezone = user.timezone || "UTC"

    DateTime.utc_now()
    |> DateTime.shift_zone!(timezone)
    |> Map.fetch!(:hour)
  end

  defp enqueue_prowl_job(notification_id) do
    BackyardGarden.Workers.ProwlNotifierJob.new(%{"notification_id" => notification_id})
    |> Oban.insert()
  end
end
