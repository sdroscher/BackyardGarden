defmodule BackyardGarden.Repo.Migrations.AddAuthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :auth0_id, :string
      add :location, :string
    end

    create unique_index(:users, [:auth0_id])
  end
end
