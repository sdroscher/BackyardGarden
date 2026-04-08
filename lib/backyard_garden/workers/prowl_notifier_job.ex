defmodule BackyardGarden.Workers.ProwlNotifierJob do
  @moduledoc """
  Oban job to send a notification via Prowl API.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  alias BackyardGarden.{Repo, Notifications, Users}
  alias BackyardGarden.Workers.ProwlClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}}) do
    notification = Repo.get!(Notifications.Notification, notification_id)
    user = Repo.get!(Users.User, notification.user_id)

    case send_prowl(user, notification) do
      {:ok, _response} ->
        Notifications.mark_sent(notification, %{
          "sent_at" => DateTime.utc_now(),
          "prowl_response" => "success"
        })

        Logger.info("Prowl notification sent for user #{user.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send Prowl notification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_prowl(user, notification) do
    ProwlClient.send_notification(user.prowl_api_key, %{
      event: notification.type,
      description: notification.message,
      priority: 0
    })
  end
end
