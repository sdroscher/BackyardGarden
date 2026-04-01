defmodule BackyardGarden.Repo.Migrations.CreateSupplierProducts do
  use Ecto.Migration

  def change do
    create table(:supplier_products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :supplier, :string, null: false
      add :shopify_product_id, :integer, null: false
      add :handle, :string, null: false
      add :title, :string, null: false
      add :product_type, :string
      add :tags, :string
      add :description_html, :text
      add :url, :string, null: false
      add :scraped_at, :utc_datetime

      timestamps()
    end

    create unique_index(:supplier_products, [:supplier, :shopify_product_id])
    create index(:supplier_products, [:supplier])
    create index(:supplier_products, [:title])
  end
end
