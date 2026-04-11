defmodule BackyardGarden.Seeds.Seed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "seeds" do
    field :name, :string
    field :brand, :string
    field :type, :string
    field :cycle, :string
    field :planting_method, :string
    field :ideal_planting_time, :string
    field :maturity_days, :integer
    field :sun_requirement, :string
    field :source_url, :string
    field :notes, :string
    field :weeks_to_start_indoors, :integer
    field :hardening_days, :integer

    belongs_to :user, BackyardGarden.Users.User
    belongs_to :supplier_product, BackyardGarden.SupplierCatalog.SupplierProduct, type: :binary_id

    timestamps()
  end

  def changeset(seed, attrs) do
    seed
    |> cast(attrs, [
      :user_id,
      :name,
      :brand,
      :type,
      :cycle,
      :planting_method,
      :ideal_planting_time,
      :maturity_days,
      :sun_requirement,
      :source_url,
      :notes,
      :weeks_to_start_indoors,
      :hardening_days,
      :supplier_product_id
    ])
    |> validate_required([:name, :user_id])
  end
end
