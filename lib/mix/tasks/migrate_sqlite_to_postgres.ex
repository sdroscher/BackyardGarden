defmodule Mix.Tasks.Migrate.SqliteToPostgres do
  @moduledoc """
  One-shot migration of dev data from SQLite to Postgres.

  Reads each table via the SQLite repo (so Ecto handles binary UUID decoding
  and Cloak decrypts encrypted fields), then inserts into Postgres.
  Safe to re-run — uses on_conflict: :nothing.

      mix migrate.sqlite_to_postgres
  """

  use Mix.Task

  alias BackyardGarden.GardenZones.GardenZone
  alias BackyardGarden.Notifications.Notification
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Repo
  alias BackyardGarden.RepoSQLite
  alias BackyardGarden.Seeds.Seed
  alias BackyardGarden.SupplierCatalog.SupplierProduct
  alias BackyardGarden.Users.User

  # FK-safe insertion order: parents before children
  @schemas [
    {"users", User},
    {"supplier_products", SupplierProduct},
    {"seeds", Seed},
    {"garden_zones", GardenZone},
    {"plantings", Planting},
    {"notifications", Notification}
  ]

  @impl Mix.Task
  def run(_args) do
    if Mix.env() == :prod do
      Mix.raise("mix migrate.sqlite_to_postgres must not be run in production.")
    end

    # Set log level before app.start so Ecto query logs don't flood the output
    Logger.configure(level: :warning)
    Mix.Task.run("app.start")

    case RepoSQLite.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Mix.shell().info("Starting SQLite → Postgres migration...\n")

    Enum.each(@schemas, fn {table, schema} ->
      rows = RepoSQLite.all(schema)
      fields = schema.__schema__(:fields)
      maps = Enum.map(rows, &Map.take(&1, fields))

      {count, _} = Repo.insert_all(schema, maps, on_conflict: :nothing)
      Mix.shell().info("  #{table}: #{count}/#{length(rows)} rows migrated")
    end)

    Mix.shell().info("\nMigration complete.")
  end
end
