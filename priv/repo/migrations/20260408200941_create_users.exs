defmodule BackyardGarden.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :timezone, :string, default: "America/Vancouver"
      add :prowl_api_key, :string
      add :notifications_enabled, :boolean, default: true

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
