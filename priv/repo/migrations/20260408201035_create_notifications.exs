defmodule BackyardGarden.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :planting_id, references(:plantings, type: :binary_id, on_delete: :nilify_all)
      add :type, :string, null: false
      add :message, :text, null: false
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :prowl_response, :string

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:sent_at])
  end
end
