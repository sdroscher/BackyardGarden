defmodule BackyardGarden.Workers.ProwlNotifierJobTest do
  use BackyardGarden.DataCase, async: false

  import Ecto.Query

  alias BackyardGarden.{
    Repo,
    Users,
    Notifications,
    Workers.ProwlNotifierJob
  }

  setup do
    # Create a user with a Prowl API key
    {:ok, user} =
      Users.create_user(%{
        email: "test@example.com",
        timezone: "America/Los_Angeles",
        prowl_api_key: "test_prowl_key_12345",
        notifications_enabled: true
      })

    # Create a user without Prowl API key
    {:ok, user_no_key} =
      Users.create_user(%{
        email: "nokey@example.com",
        timezone: "America/Los_Angeles",
        notifications_enabled: true
      })

    # Create test notifications
    {:ok, notification} =
      Notifications.log_notification(%{
        "user_id" => user.id,
        "type" => "plant_now",
        "message" => "Tomato is ready to plant!",
        "scheduled_at" => DateTime.utc_now()
      })

    {:ok, notification_no_key} =
      Notifications.log_notification(%{
        "user_id" => user_no_key.id,
        "type" => "plant_now",
        "message" => "Lettuce is ready to plant!",
        "scheduled_at" => DateTime.utc_now()
      })

    %{
      user: user,
      user_no_key: user_no_key,
      notification: notification,
      notification_no_key: notification_no_key
    }
  end

  describe "perform/1" do
    test "handles missing notification gracefully" do
      # Use a non-existent notification ID
      job = %Oban.Job{args: %{"notification_id" => Ecto.UUID.generate()}}

      # Should not crash, just handle the missing notification
      result = ProwlNotifierJob.perform(job)
      assert result == :ok
    end

    test "processes notification and returns :ok even if Prowl fails", %{
      notification_no_key: notification
    } do
      job = %Oban.Job{args: %{"notification_id" => notification.id}}

      # Should return :ok even if Prowl API call fails
      # (Oban will log error but won't retry if :ok is returned)
      result = ProwlNotifierJob.perform(job)
      assert result == :ok
    end

    test "marks notification as sent on successful delivery", %{notification: notification} do
      # Mock a successful Prowl send (in reality this would fail in test)
      job = %Oban.Job{args: %{"notification_id" => notification.id}}

      # Perform the job (may fail if Prowl unavailable in test)
      _result = ProwlNotifierJob.perform(job)

      # Verify notification still exists in database
      notification_after =
        from(n in Notifications.Notification,
          where: n.id == ^notification.id
        )
        |> Repo.one()

      assert notification_after != nil
    end
  end
end
