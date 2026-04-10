defmodule BackyardGarden.Plantings do
  @moduledoc """
  Context for managing garden plantings.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.Plantings.Planting

  @doc "Returns all plantings for a user, preloaded with seed and zone, ordered by inserted_at desc."
  def list_plantings(user_id) do
    Planting
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc "Returns all plantings for a user with the given status, preloaded with seed and zone."
  def list_plantings_by_status(user_id, status) do
    Planting
    |> where([p], p.user_id == ^user_id and p.status == ^status)
    |> order_by([p], desc: p.inserted_at)
    |> preload([:seed, :zone])
    |> Repo.all()
  end

  @doc """
  Returns plantings for a user relevant to the given month — either planted in that month,
  or with a harvest due date (planted_at + seed.maturity_days) in that month.

  The harvest-due filter is applied in Elixir (not SQL) because it requires
  `seed.maturity_days` from the preloaded association — pushing this into a
  SQL expression would require a join-based computed column, which is impractical
  with the current schema.
  """
  def list_plantings_for_month(user_id, %Date{} = first_day) do
    last_day = Date.end_of_month(first_day)

    Planting
    |> where([p], p.user_id == ^user_id and not is_nil(p.planted_at))
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

  @doc """
  Returns the calculated sow date for a planned seedling planting, or nil if any
  required value (planted_at, weeks_to_start_indoors, hardening_days) is missing.
  """
  def sow_date(%{planted_at: nil}), do: nil
  def sow_date(%{planted_at: _, seed: %{weeks_to_start_indoors: nil}}), do: nil
  def sow_date(%{planted_at: _, seed: %{hardening_days: nil}}), do: nil

  def sow_date(%{
        planted_at: transplant,
        seed: %{weeks_to_start_indoors: weeks, hardening_days: harden}
      }) do
    Date.add(transplant, -(weeks * 7 + harden))
  end

  @doc """
  Returns the calculated hardening start date for a sown seedling planting, or nil
  if any required value (sown_at, weeks_to_start_indoors) is missing.
  """
  def hardening_start_date(%{sown_at: nil}), do: nil
  def hardening_start_date(%{sown_at: _, seed: %{weeks_to_start_indoors: nil}}), do: nil

  def hardening_start_date(%{sown_at: sown, seed: %{weeks_to_start_indoors: weeks}}) do
    Date.add(sown, weeks * 7)
  end

  @doc """
  Returns the projected transplant date for a sown seedling planting, or nil if any
  required value (sown_at, weeks_to_start_indoors, hardening_days) is missing.
  """
  def projected_transplant_date(%{sown_at: nil}), do: nil
  def projected_transplant_date(%{sown_at: _, seed: %{weeks_to_start_indoors: nil}}), do: nil
  def projected_transplant_date(%{sown_at: _, seed: %{hardening_days: nil}}), do: nil

  def projected_transplant_date(%{
        sown_at: sown,
        seed: %{weeks_to_start_indoors: weeks, hardening_days: harden}
      }) do
    Date.add(sown, weeks * 7 + harden)
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
