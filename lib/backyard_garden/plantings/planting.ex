defmodule BackyardGarden.Plantings.Planting do
  @moduledoc """
  Schema for a seed planting event — tracks status, dates, location, and notes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(planned planted harvested)

  schema "plantings" do
    field :status, :string, default: "planned"
    field :planted_at, :date
    field :harvested_at, :date
    field :location, :string
    field :notes, :string

    belongs_to :seed, BackyardGarden.Seeds.Seed
    belongs_to :zone, BackyardGarden.GardenZones.GardenZone

    timestamps()
  end

  def changeset(planting, attrs) do
    planting
    |> cast(attrs, [:seed_id, :zone_id, :status, :planted_at, :harvested_at, :location, :notes])
    |> validate_required([:seed_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:seed_id)
    |> foreign_key_constraint(:zone_id)
  end
end
