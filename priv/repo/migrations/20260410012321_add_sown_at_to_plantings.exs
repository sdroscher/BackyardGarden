defmodule BackyardGarden.Repo.Migrations.AddSownAtToPlantings do
  use Ecto.Migration

  def change do
    alter table(:plantings) do
      add :sown_at, :date
    end
  end
end
