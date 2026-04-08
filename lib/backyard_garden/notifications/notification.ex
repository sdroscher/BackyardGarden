defmodule BackyardGarden.Notifications.Notification do
  @moduledoc """
  Schema for tracking sent notifications — type, message, delivery response.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(plant_now harvest_soon frost_warning)

  schema "notifications" do
    field :type, :string
    field :message, :string
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :prowl_response, :string

    belongs_to :user, BackyardGarden.Users.User

    belongs_to :planting, BackyardGarden.Plantings.Planting,
      type: :binary_id,
      foreign_key: :planting_id

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :user_id,
      :planting_id,
      :type,
      :message,
      :scheduled_at,
      :sent_at,
      :prowl_response
    ])
    |> validate_required([:user_id, :type, :message])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:planting_id)
  end
end
