defmodule BackyardGarden.Repo.Migrations.AddUserIdToGardenZones do
  use Ecto.Migration

  def change do
    alter table(:garden_zones) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:garden_zones, [:user_id])
  end
end
