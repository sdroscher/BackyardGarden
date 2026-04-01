defmodule BackyardGarden.Repo do
  use Ecto.Repo,
    otp_app: :backyard_garden,
    adapter: Ecto.Adapters.Postgres
end
