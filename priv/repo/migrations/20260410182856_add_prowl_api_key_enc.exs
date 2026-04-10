defmodule BackyardGarden.Repo.Migrations.AddProwlApiKeyEnc do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :prowl_api_key_enc, :binary
    end
  end
end
