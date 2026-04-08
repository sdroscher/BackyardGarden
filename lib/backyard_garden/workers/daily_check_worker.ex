defmodule BackyardGarden.Workers.DailyCheckWorker do
  @moduledoc """
  Daily scheduled job to check for plant-now and harvest-soon conditions,
  enqueuing Prowl notifications for each user.

  Runs at 7am local time via Oban.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  import Ecto.Query

  alias BackyardGarden.{Repo, Users, Dashboard, Notifications}
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Notifications.Notification

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting daily check for plant-now and harvest-soon")

    # Get all users with notifications enabled
    users_with_prowl =
      Users.list_users()
      |> Enum.filter(&(&1.notifications_enabled and &1.prowl_api_key))

    # For each user, check conditions and enqueue notifications
    Enum.each(users_with_prowl, &check_user_conditions/1)

    :ok
  end

  defp check_user_conditions(user) do
    today = Date.utc_today()

    # Plant-now checks
    check_plant_now(user, today)

    # Harvest-soon checks
    check_harvest_soon(user, today)
  end

  defp check_plant_now(user, date) do
    # Get seeds in planting window that aren't already planted
    plant_now_seeds = Dashboard.plant_now_seeds(date)

    Enum.each(plant_now_seeds, fn seed ->
      # Check if user already received a plant_now notification for this seed recently
      unless recently_notified?(user.id, seed.id, "plant_now") do
        message = "#{seed.name} is ready to plant! Ideal window is open now."

        {:ok, notification} =
          Notifications.log_notification(%{
            "user_id" => user.id,
            "type" => "plant_now",
            "message" => message,
            "scheduled_at" => DateTime.utc_now()
          })

        # Enqueue Prowl job to send the notification
        enqueue_prowl_job(notification.id)
      end
    end)
  end

  defp check_harvest_soon(user, date) do
    # Get plantings that are harvest_soon (within 7 days)
    harvest_soon =
      Planting
      |> where([p], p.user_id == ^user.id and p.status == "planted")
      |> Repo.all()
      |> Enum.filter(&harvest_window_open?(&1, date))

    Enum.each(harvest_soon, fn planting ->
      unless recently_notified?(user.id, planting.id, "harvest_soon") do
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

  defp harvest_window_open?(%Planting{planted_at: nil}, _date), do: false

  defp harvest_window_open?(planting, date) do
    seed = Repo.preload(planting, :seed).seed
    days_since_planted = Date.diff(date, planting.planted_at)
    days_until_mature = seed.maturity_days - days_since_planted
    days_until_mature >= 0 and days_until_mature <= 7
  end

  defp recently_notified?(user_id, _seed_or_planting_id, type) do
    days_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    Notification
    |> where([n], n.user_id == ^user_id and n.type == ^type)
    |> where([n], n.inserted_at > ^days_ago)
    |> Repo.exists?()
  end

  defp enqueue_prowl_job(notification_id) do
    BackyardGarden.Workers.ProwlNotifierJob.new(%{"notification_id" => notification_id})
    |> Oban.insert()
  end
end
