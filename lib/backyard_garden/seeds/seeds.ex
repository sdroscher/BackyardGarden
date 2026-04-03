defmodule BackyardGarden.Seeds do
  @moduledoc """
  Context for managing seed reference data.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Seeds.Seed

  @doc "Returns all seeds matching the given filters, sorted by name or specified field."
  def list_seeds(filters \\ %{}) do
    Seed
    |> filter_by(:type, filters[:type])
    |> filter_by(:brand, filters[:brand])
    |> filter_by(:cycle, filters[:cycle])
    |> filter_by(:planting_method, filters[:planting_method])
    |> filter_by(:sun_requirement, filters[:sun_requirement])
    |> filter_by_search(filters[:search])
    |> apply_sort(filters[:sort_field], filters[:sort_dir])
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

  @doc "Updates a seed. Returns {:ok, seed} or {:error, changeset}."
  def update_seed(%Seed{} = seed, attrs) do
    seed
    |> Seed.changeset(attrs)
    |> Repo.update()
  end

  @doc "Returns a single seed by id, or nil if not found."
  def get_seed(id), do: Repo.get(Seed, id)

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

  @doc "Returns sorted distinct planting methods present in the database."
  def list_planting_methods do
    Seed
    |> where([s], not is_nil(s.planting_method) and s.planting_method != "")
    |> select([s], s.planting_method)
    |> distinct(true)
    |> order_by([s], s.planting_method)
    |> Repo.all()
  end

  @doc "Returns sorted distinct sun requirements present in the database."
  def list_sun_requirements do
    Seed
    |> where([s], not is_nil(s.sun_requirement) and s.sun_requirement != "")
    |> select([s], s.sun_requirement)
    |> distinct(true)
    |> order_by([s], s.sun_requirement)
    |> Repo.all()
  end

  # --- Private query helpers ---

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, _field, ""), do: query
  defp filter_by(query, field, value), do: where(query, [s], field(s, ^field) == ^value)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    escaped =
      search |> String.downcase() |> String.replace("%", "\\%") |> String.replace("_", "\\_")

    term = "%#{escaped}%"

    where(
      query,
      [s],
      like(fragment("lower(?)", s.name), ^term) or
        like(fragment("lower(?)", s.brand), ^term)
    )
  end

  defp apply_sort(query, nil, _dir), do: order_by(query, [s], s.name)
  defp apply_sort(query, "", _dir), do: order_by(query, [s], s.name)

  defp apply_sort(query, field, dir) do
    sort_field = to_sort_atom(field)
    sort_dir = if dir == :desc, do: :desc, else: :asc
    order_by(query, [s], [{^sort_dir, field(s, ^sort_field)}])
  end

  defp to_sort_atom("type"), do: :type
  defp to_sort_atom("brand"), do: :brand
  defp to_sort_atom("cycle"), do: :cycle
  defp to_sort_atom("ideal_planting_time"), do: :ideal_planting_time
  defp to_sort_atom(_), do: :name
end
