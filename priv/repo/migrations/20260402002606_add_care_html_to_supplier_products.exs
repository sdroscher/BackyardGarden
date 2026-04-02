defmodule BackyardGarden.Repo.Migrations.AddCareHtmlToSupplierProducts do
  use Ecto.Migration

  def change do
    alter table(:supplier_products) do
      add :care_html, :text
    end
  end
end
