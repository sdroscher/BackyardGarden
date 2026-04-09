defmodule BackyardGarden.Repo.Migrations.AddSeedIdToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :seed_id, :binary_id, null: true
    end

    create index(:notifications, [:seed_id])
  end
end
