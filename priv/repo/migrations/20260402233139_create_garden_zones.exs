defmodule BackyardGarden.Repo.Migrations.CreateGardenZones do
  use Ecto.Migration

  def change do
    create table(:garden_zones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :sun_exposures, :string
      add :allowed_types, :string
      add :allowed_cycles, :string

      timestamps()
    end

    create index(:garden_zones, [:name])
  end
end
