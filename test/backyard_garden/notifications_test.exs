defmodule BackyardGarden.NotificationsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Notifications

  describe "log_notification/1" do
    test "creates a notification record" do
      user = user_fixture()

      attrs = %{
        "user_id" => user.id,
        "type" => "plant_now",
        "message" => "Time to plant spinach",
        "scheduled_at" => DateTime.utc_now()
      }

      assert {:ok, notif} = Notifications.log_notification(attrs)
      assert notif.type == "plant_now"
      assert notif.message == "Time to plant spinach"
    end

    test "requires user_id, type, message" do
      attrs = %{"type" => "plant_now"}
      assert {:error, changeset} = Notifications.log_notification(attrs)
      assert errors_on(changeset)[:user_id]
      assert errors_on(changeset)[:message]
    end
  end

  describe "mark_sent/2" do
    test "updates sent_at and prowl_response" do
      user = user_fixture()

      {:ok, notif} =
        Notifications.log_notification(%{
          "user_id" => user.id,
          "type" => "plant_now",
          "message" => "Test"
        })

      assert {:ok, updated} =
               Notifications.mark_sent(notif, %{
                 "sent_at" => DateTime.utc_now(),
                 "prowl_response" => "success"
               })

      assert updated.prowl_response == "success"
      assert not is_nil(updated.sent_at)
    end
  end

  # Fixture helper
  defp user_fixture do
    {:ok, user} =
      BackyardGarden.Users.create_user(%{
        "email" => "test#{System.unique_integer()}@example.com"
      })

    user
  end
end
