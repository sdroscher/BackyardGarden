defmodule BackyardGarden.RepoSQLite do
  @moduledoc "Temporary SQLite repo used only by mix migrate.sqlite_to_postgres."

  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: Ecto.Adapters.SQLite3
end
