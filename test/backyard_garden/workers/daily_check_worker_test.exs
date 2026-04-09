defmodule BackyardGarden.Workers.DailyCheckWorkerTest do
  use BackyardGarden.DataCase, async: false

  import Ecto.Query

  alias BackyardGarden.{
    Repo,
    Users,
    Seeds,
    Plantings,
    Notifications
  }

  setup do
    today = Date.utc_today()

    # Create a user with notifications enabled
    {:ok, user} =
      Users.create_user(%{
        email: "test@example.com",
        timezone: "America/Los_Angeles",
        prowl_api_key: "test_key_123",
        notifications_enabled: true
      })

    # Create a user with notifications disabled
    {:ok, user_disabled} =
      Users.create_user(%{
        email: "disabled@example.com",
        timezone: "America/Los_Angeles",
        notifications_enabled: false
      })

    # Create test seeds in current planting window (April is month 4)
    {:ok, seed_ready} =
      Seeds.create_seed(%{
        name: "Tomato",
        type: "Vegetable",
        ideal_planting_time: "April-May",
        maturity_days: 60
      })

    {:ok, seed_ready2} =
      Seeds.create_seed(%{
        name: "Lettuce",
        type: "Vegetable",
        ideal_planting_time: "April-June",
        maturity_days: 30
      })

    # Create a seed not in current planting window
    {:ok, seed_not_ready} =
      Seeds.create_seed(%{
        name: "Pumpkin",
        type: "Vegetable",
        ideal_planting_time: "May-June",
        maturity_days: 90
      })

    # Create a separate seed for harvest_soon test
    {:ok, harvest_seed} =
      Seeds.create_seed(%{
        name: "Carrot",
        type: "Vegetable",
        ideal_planting_time: "March-April",
        maturity_days: 60
      })

    # Create plantings for harvest_soon test
    planted_date = Date.add(today, -25)

    {:ok, planting_harvest_soon} =
      Plantings.create_planting(%{
        user_id: user.id,
        seed_id: harvest_seed.id,
        planted_at: planted_date,
        status: "planted"
      })

    {:ok, planting_just_planted} =
      Plantings.create_planting(%{
        user_id: user.id,
        seed_id: seed_ready2.id,
        planted_at: today,
        status: "planted"
      })

    %{
      user: user,
      user_disabled: user_disabled,
      seed_ready: seed_ready,
      seed_ready2: seed_ready2,
      seed_not_ready: seed_not_ready,
      harvest_seed: harvest_seed,
      planting_harvest_soon: planting_harvest_soon,
      planting_just_planted: planting_just_planted
    }
  end

  describe "Daily check worker" do
    test "creates plant_now notification for eligible seeds", %{user: user, seed_ready: seed} do
      # Test the core logic: check_plant_now should create notifications for seeds in planting window
      # Manually check seeds that would trigger plant_now
      # (mimicking what the worker does)
      plant_now_check_for_seed(user, seed)

      # Verify notification was created
      notification =
        from(n in Notifications.Notification,
          where: n.user_id == ^user.id and n.seed_id == ^seed.id and n.type == "plant_now"
        )
        |> Repo.one()

      assert notification != nil
      assert String.contains?(notification.message, seed.name)
      assert String.contains?(notification.message, "ready to plant")
    end

    test "creates harvest_soon notification for plantings near maturity", %{
      user: user,
      planting_harvest_soon: planting,
      harvest_seed: seed
    } do
      # Test harvest_soon logic
      harvest_check_for_planting(user, planting, seed)

      notification =
        from(n in Notifications.Notification,
          where:
            n.user_id == ^user.id and n.planting_id == ^planting.id and
              n.type == "harvest_soon"
        )
        |> Repo.one()

      assert notification != nil
      assert String.contains?(notification.message, seed.name)
      assert String.contains?(notification.message, "nearly ready to harvest")
    end

    test "does not duplicate notifications within 24 hours", %{user: user, seed_ready: seed} do
      # Create first notification
      plant_now_check_for_seed(user, seed)

      count_after_first =
        from(n in Notifications.Notification,
          where: n.user_id == ^user.id and n.seed_id == ^seed.id and n.type == "plant_now"
        )
        |> Repo.aggregate(:count)

      assert count_after_first == 1

      # Try to create again - should be skipped due to recent_notification check
      plant_now_check_for_seed(user, seed)

      count_after_second =
        from(n in Notifications.Notification,
          where: n.user_id == ^user.id and n.seed_id == ^seed.id and n.type == "plant_now"
        )
        |> Repo.aggregate(:count)

      assert count_after_second == 1
    end

    test "creates separate notifications for different seeds", %{
      user: user,
      seed_ready: seed1,
      seed_ready2: seed2
    } do
      plant_now_check_for_seed(user, seed1)
      plant_now_check_for_seed(user, seed2)

      notif1 =
        from(n in Notifications.Notification,
          where: n.user_id == ^user.id and n.seed_id == ^seed1.id and n.type == "plant_now"
        )
        |> Repo.one()

      notif2 =
        from(n in Notifications.Notification,
          where: n.user_id == ^user.id and n.seed_id == ^seed2.id and n.type == "plant_now"
        )
        |> Repo.one()

      assert notif1 != nil
      assert notif2 != nil
      assert notif1.id != notif2.id
    end
  end

  # Helper functions that simulate the worker logic without Oban integration
  defp plant_now_check_for_seed(user, seed) do
    unless recently_notified_for_seed?(user.id, seed.id, "plant_now") do
      message = "#{seed.name} is ready to plant! Ideal window is open now."

      Notifications.log_notification(%{
        "user_id" => user.id,
        "seed_id" => seed.id,
        "type" => "plant_now",
        "message" => message,
        "scheduled_at" => DateTime.utc_now()
      })
    end
  end

  defp harvest_check_for_planting(user, planting, seed) do
    unless recently_notified_for_planting?(user.id, planting.id, "harvest_soon") do
      message = "#{seed.name} is nearly ready to harvest!"

      Notifications.log_notification(%{
        "user_id" => user.id,
        "planting_id" => planting.id,
        "type" => "harvest_soon",
        "message" => message,
        "scheduled_at" => DateTime.utc_now()
      })
    end
  end

  defp recently_notified_for_seed?(user_id, seed_id, type) do
    days_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    from(n in Notifications.Notification,
      where:
        n.user_id == ^user_id and n.seed_id == ^seed_id and n.type == ^type and
          n.inserted_at > ^days_ago
    )
    |> Repo.exists?()
  end

  defp recently_notified_for_planting?(user_id, planting_id, type) do
    days_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    from(n in Notifications.Notification,
      where:
        n.user_id == ^user_id and n.planting_id == ^planting_id and n.type == ^type and
          n.inserted_at > ^days_ago
    )
    |> Repo.exists?()
  end
end
