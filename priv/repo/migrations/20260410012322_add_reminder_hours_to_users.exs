defmodule BackyardGarden.Repo.Migrations.AddReminderHoursToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :morning_reminder_hour, :integer, default: 8, null: false
      add :evening_reminder_hour, :integer, default: 18, null: false
    end
  end
end
