defmodule BackyardGarden.Repo do
  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: if(Mix.env() == :test, do: Ecto.Adapters.SQLite3, else: Ecto.Adapters.Postgres)
end
