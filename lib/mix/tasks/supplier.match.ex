defmodule Mix.Tasks.Supplier.Match do
  @moduledoc """
  Fuzzy-matches seeds to supplier products by name similarity (Jaro distance).
  Auto-links seeds with score >= 0.90. Prints a review list for 0.75–0.89.
  Seeds with score < 0.75 are left unlinked.

  Run mix supplier.scrape first to populate supplier_products.

  Usage:
      mix supplier.match
  """

  use Mix.Task

  import Ecto.Query
  alias BackyardGarden.{Repo, Seeds, SupplierCatalog}
  alias BackyardGarden.Seeds.Seed

  @shortdoc "Match seeds to supplier products by name similarity"

  @auto_threshold 0.90
  @review_threshold 0.75

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    seeds = Seeds.list_seeds()

    {auto_count, review, unmatched} =
      Enum.reduce(seeds, {0, [], []}, fn seed, {auto_count, review_acc, unmatched_acc} ->
        case SupplierCatalog.find_match_for_seed(seed) do
          {nil, _} ->
            {auto_count, review_acc, [seed.name | unmatched_acc]}

          {product, score} when score >= @auto_threshold ->
            Repo.update_all(from(s in Seed, where: s.id == ^seed.id),
              set: [supplier_product_id: product.id]
            )

            {auto_count + 1, review_acc, unmatched_acc}

          {product, score} when score >= @review_threshold ->
            {auto_count, [{seed, product, score} | review_acc], unmatched_acc}

          {_, _} ->
            {auto_count, review_acc, [seed.name | unmatched_acc]}
        end
      end)

    Mix.shell().info("Auto-linked #{auto_count} seeds.\n")
    print_review_list(review)
    print_unmatched(unmatched)
  end

  defp print_review_list([]), do: :ok

  defp print_review_list(review) do
    Mix.shell().info(
      "Review needed (confirm with: mix supplier.link <seed_id> <supplier_product_id>):"
    )

    Enum.each(review, fn {seed, product, score} ->
      score_str = :erlang.float_to_binary(score, decimals: 2)

      supplier_label =
        product.supplier
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)

      Mix.shell().info(~s|  "#{seed.name}"  →  "#{product.title}" (#{supplier_label}, #{score_str})|)
      Mix.shell().info(~s|    seed_id=#{seed.id}  product_id=#{product.id}|)
    end)

    Mix.shell().info("")
  end

  defp print_unmatched([]), do: :ok

  defp print_unmatched(unmatched) do
    Mix.shell().info("Unmatched seeds (#{length(unmatched)}): #{Enum.join(unmatched, ", ")}")
  end
end
