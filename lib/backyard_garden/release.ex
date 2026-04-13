defmodule BackyardGarden.Release do
  @moduledoc """
  Tasks that run inside the production release binary, where Mix is unavailable.
  Called by the Fly.io release command before traffic switches to the new deployment.
  """

  @app :backyard_garden

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp load_app, do: Application.load(@app)

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end
