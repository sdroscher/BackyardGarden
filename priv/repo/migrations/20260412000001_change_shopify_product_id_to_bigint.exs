defmodule BackyardGarden.Repo.Migrations.ChangeShopifyProductIdToBigint do
  use Ecto.Migration

  # SQLite (used in test) does not support ALTER COLUMN
  def change do
    unless BackyardGarden.Repo.__adapter__() == Ecto.Adapters.SQLite3 do
      alter table(:supplier_products) do
        modify :shopify_product_id, :bigint
      end
    end
  end
end
