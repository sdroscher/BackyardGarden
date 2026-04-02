defmodule BackyardGarden.Repo.Migrations.CreatePlantings do
  use Ecto.Migration

  def change do
    create table(:plantings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :seed_id, references(:seeds, type: :binary_id, on_delete: :restrict), null: false
      add :zone_id, references(:garden_zones, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, default: "planned"
      add :planted_at, :date
      add :harvested_at, :date
      add :location, :string
      add :notes, :text

      timestamps()
    end

    create index(:plantings, [:seed_id])
    create index(:plantings, [:status])
    create index(:plantings, [:planted_at])
  end
end
