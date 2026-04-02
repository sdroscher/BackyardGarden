defmodule BackyardGarden.Plantings do
  @moduledoc """
  Context for managing garden plantings.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Plantings.Planting

  @doc "Returns all plantings preloaded with seed and zone, ordered by inserted_at desc."
  def list_plantings do
    Planting
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc "Returns all plantings with the given status, preloaded with seed and zone."
  def list_plantings_by_status(status) do
    Planting
    |> where([p], p.status == ^status)
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc """
  Returns plantings relevant to the given month — either planted in that month,
  or with a harvest due date (planted_at + seed.maturity_days) in that month.
  """
  def list_plantings_for_month(%Date{} = first_day) do
    last_day = Date.end_of_month(first_day)

    Planting
    |> where([p], not is_nil(p.planted_at))
    |> preload(:seed)
    |> Repo.all()
    |> Enum.filter(fn planting ->
      planted_in_month?(planting, first_day, last_day) or
        harvest_due_in_month?(planting, first_day, last_day)
    end)
  end

  @doc "Returns a single planting by id with seed and zone preloaded. Raises if not found."
  def get_planting!(id) do
    Planting
    |> preload([:seed, :zone])
    |> Repo.get!(id)
  end

  @doc "Creates a planting. Returns {:ok, planting} or {:error, changeset}."
  def create_planting(attrs) do
    %Planting{}
    |> Planting.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a planting. Returns {:ok, planting} or {:error, changeset}."
  def update_planting(%Planting{} = planting, attrs) do
    planting
    |> Planting.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a planting. Returns {:ok, planting} or {:error, changeset}."
  def delete_planting(%Planting{} = planting), do: Repo.delete(planting)

  @doc "Returns a changeset for a planting (used to initialise forms)."
  def change_planting(%Planting{} = planting, attrs \\ %{}) do
    Planting.changeset(planting, attrs)
  end

  # Private helpers

  defp planted_in_month?(%Planting{planted_at: date}, first_day, last_day) do
    not is_nil(date) and Date.compare(date, first_day) != :lt and
      Date.compare(date, last_day) != :gt
  end

  defp harvest_due_in_month?(%Planting{planted_at: planted_at, seed: seed}, first_day, last_day) do
    with %Date{} <- planted_at,
         maturity when is_integer(maturity) and maturity > 0 <- seed.maturity_days do
      harvest_date = Date.add(planted_at, maturity)

      Date.compare(harvest_date, first_day) != :lt and
        Date.compare(harvest_date, last_day) != :gt
    else
      _ -> false
    end
  end
end
