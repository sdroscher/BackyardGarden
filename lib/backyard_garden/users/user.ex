defmodule BackyardGarden.Users.User do
  @moduledoc """
  User schema — email, name, timezone, Prowl API key, notification preferences.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :auth0_id, :string
    field :location, :string
    field :timezone, :string, default: "America/Vancouver"
    field :prowl_api_key, BackyardGarden.Encrypted.Binary, source: :prowl_api_key_enc
    field :notifications_enabled, :boolean, default: true
    field :morning_reminder_hour, :integer, default: 8
    field :evening_reminder_hour, :integer, default: 18

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :auth0_id,
      :location,
      :timezone,
      :prowl_api_key,
      :notifications_enabled,
      :morning_reminder_hour,
      :evening_reminder_hour
    ])
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> unique_constraint(:auth0_id)
  end
end
