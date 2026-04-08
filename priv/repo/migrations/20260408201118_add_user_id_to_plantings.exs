defmodule BackyardGarden.Repo.Migrations.AddUserIdToPlantings do
  use Ecto.Migration

  def change do
    alter table(:plantings) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:plantings, [:user_id])
  end
end
