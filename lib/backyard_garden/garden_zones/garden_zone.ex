defmodule BackyardGarden.GardenZones.GardenZone do
  @moduledoc """
  Schema for a named garden zone with sun exposure and planting constraints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "garden_zones" do
    field :name, :string
    field :description, :string
    field :sun_exposures, :string
    field :allowed_types, :string
    field :allowed_cycles, :string
    belongs_to :user, BackyardGarden.Users.User

    timestamps()
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [
      :name,
      :description,
      :sun_exposures,
      :allowed_types,
      :allowed_cycles,
      :user_id
    ])
    |> validate_required([:name])
  end
end
