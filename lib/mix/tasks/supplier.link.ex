defmodule Mix.Tasks.Supplier.Link do
  @moduledoc """
  Manually links a seed to a supplier product.
  Use this to confirm borderline matches printed by mix supplier.match.

  Usage:
      mix supplier.link <seed_id> <supplier_product_id>
  """

  use Mix.Task

  import Ecto.Query
  alias BackyardGarden.{Repo, Seeds}
  alias BackyardGarden.Seeds.Seed

  @shortdoc "Link a seed to a supplier product by ID"

  @impl Mix.Task
  def run([seed_id, supplier_product_id]) do
    Mix.Task.run("app.start")
    seed = Seeds.get_seed!(seed_id)

    Repo.update_all(from(s in Seed, where: s.id == ^seed.id),
      set: [supplier_product_id: supplier_product_id]
    )

    Mix.shell().info(~s|Linked "#{seed.name}" → supplier_product #{supplier_product_id}|)
  end

  def run(_) do
    Mix.raise("Usage: mix supplier.link <seed_id> <supplier_product_id>")
  end
end
