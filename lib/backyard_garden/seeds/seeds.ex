defmodule BackyardGarden.Seeds do
  @moduledoc """
  Context for managing seed reference data.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Seeds.Seed

  @doc "Returns all seeds matching the given filters, sorted by name."
  def list_seeds(filters \\ %{}) do
    Seed
    |> filter_by(:type, filters[:type])
    |> filter_by(:brand, filters[:brand])
    |> filter_by(:cycle, filters[:cycle])
    |> filter_by_search(filters[:search])
    |> order_by([s], s.name)
    |> Repo.all()
  end

  @doc "Returns a single seed by id. Raises Ecto.NoResultsError if not found."
  def get_seed!(id), do: Repo.get!(Seed, id)

  @doc "Returns a single seed by id with supplier_product preloaded. Raises if not found."
  def get_seed_with_supplier!(id) do
    get_seed!(id) |> Repo.preload(:supplier_product)
  end

  @doc "Creates a seed. Returns {:ok, seed} or {:error, changeset}."
  def create_seed(attrs) do
    %Seed{}
    |> Seed.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Returns sorted distinct seed types present in the database."
  def list_types do
    Seed
    |> where([s], not is_nil(s.type) and s.type != "")
    |> select([s], s.type)
    |> distinct(true)
    |> order_by([s], s.type)
    |> Repo.all()
  end

  @doc "Returns sorted distinct seed brands present in the database."
  def list_brands do
    Seed
    |> where([s], not is_nil(s.brand) and s.brand != "")
    |> select([s], s.brand)
    |> distinct(true)
    |> order_by([s], s.brand)
    |> Repo.all()
  end

  @doc "Returns sorted distinct seed cycles present in the database."
  def list_cycles do
    Seed
    |> where([s], not is_nil(s.cycle) and s.cycle != "")
    |> select([s], s.cycle)
    |> distinct(true)
    |> order_by([s], s.cycle)
    |> Repo.all()
  end

  # --- Private query helpers ---

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, _field, ""), do: query
  defp filter_by(query, field, value), do: where(query, [s], field(s, ^field) == ^value)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    escaped = search |> String.downcase() |> String.replace("%", "\\%") |> String.replace("_", "\\_")
    term = "%#{escaped}%"

    where(
      query,
      [s],
      like(fragment("lower(?)", s.name), ^term) or
        like(fragment("lower(?)", s.brand), ^term)
    )
  end
end
