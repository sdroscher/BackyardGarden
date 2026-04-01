defmodule BackyardGarden.Repo.Migrations.AddSupplierProductIdToSeeds do
  use Ecto.Migration

  def change do
    alter table(:seeds) do
      add :supplier_product_id,
          references(:supplier_products, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
