defmodule BackyardGarden.Repo.Migrations.AddUserIdToSeeds do
  use Ecto.Migration

  def change do
    alter table(:seeds) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:seeds, [:user_id])
  end
end
