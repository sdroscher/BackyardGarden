defmodule BackyardGarden.SupplierCatalog.SupplierProduct do
  @moduledoc """
  Schema for a product entry scraped from a seed supplier's Shopify catalog.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "supplier_products" do
    field :supplier, :string
    field :shopify_product_id, :id
    field :handle, :string
    field :title, :string
    field :product_type, :string
    field :tags, :string
    field :description_html, :string
    field :care_html, :string
    field :url, :string
    field :scraped_at, :utc_datetime

    timestamps()
  end

  def changeset(supplier_product, attrs) do
    supplier_product
    |> cast(attrs, [
      :supplier,
      :shopify_product_id,
      :handle,
      :title,
      :product_type,
      :tags,
      :description_html,
      :care_html,
      :url,
      :scraped_at
    ])
    |> validate_required([:supplier, :shopify_product_id, :handle, :title, :url])
    |> unique_constraint([:supplier, :shopify_product_id])
  end
end
