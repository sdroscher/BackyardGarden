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
    field :timezone, :string, default: "America/Vancouver"
    field :prowl_api_key, :string
    field :notifications_enabled, :boolean, default: true

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :timezone, :prowl_api_key, :notifications_enabled])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
