defmodule BackyardGarden.Repo.Migrations.AddSeedlingFieldsToSeeds do
  use Ecto.Migration

  def change do
    alter table(:seeds) do
      add :weeks_to_start_indoors, :integer
      add :hardening_days, :integer
    end
  end
end
