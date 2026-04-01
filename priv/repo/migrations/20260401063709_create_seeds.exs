defmodule BackyardGarden.Repo.Migrations.CreateSeeds do
  use Ecto.Migration

  def change do
    create table(:seeds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :brand, :string
      add :type, :string
      add :cycle, :string
      add :planting_method, :string
      add :ideal_planting_time, :string
      add :maturity_days, :integer
      add :sun_requirement, :string
      add :source_url, :string
      add :notes, :text

      timestamps()
    end

    create index(:seeds, [:name])
    create index(:seeds, [:type])
    create index(:seeds, [:brand])
    create index(:seeds, [:cycle])
  end
end
