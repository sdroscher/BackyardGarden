defmodule BackyardGarden.Repo.Migrations.ChangeSupplierProductsTagsToText do
  use Ecto.Migration

  # SQLite (used in test) does not support ALTER COLUMN
  def change do
    unless BackyardGarden.Repo.__adapter__() == Ecto.Adapters.SQLite3 do
      alter table(:supplier_products) do
        modify :tags, :text
      end
    end
  end
end
