defmodule BackyardGarden.Notifications do
  @moduledoc "Notifications context — log and track notification delivery."

  import Ecto.Query

  alias BackyardGarden.Repo
  alias BackyardGarden.Notifications.Notification

  @doc "Log a new notification."
  def log_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Mark a notification as sent with Prowl response."
  def mark_sent(notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc "Get recent notifications for a user."
  def recent_notifications(user_id, limit \\ 10) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Get pending notifications (scheduled but not sent)."
  def pending_notifications do
    Notification
    |> where([n], is_nil(n.sent_at))
    |> order_by([n], asc: n.scheduled_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end
end
