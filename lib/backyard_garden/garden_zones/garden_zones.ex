defmodule BackyardGarden.GardenZones do
  @moduledoc """
  Context for managing garden zones and zone recommendations.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.GardenZones.GardenZone

  @doc "Returns all zones for a user, ordered by name."
  def list_zones(user_id) do
    GardenZone
    |> where([z], z.user_id == ^user_id)
    |> order_by([z], z.name)
    |> Repo.all()
  end

  @doc "Returns a single zone by id. Raises if not found."
  def get_zone!(id), do: Repo.get!(GardenZone, id)

  @doc "Creates a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def create_zone(attrs) do
    %GardenZone{}
    |> GardenZone.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def update_zone(%GardenZone{} = zone, attrs) do
    zone
    |> GardenZone.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a garden zone. Returns {:ok, zone} or {:error, changeset}."
  def delete_zone(%GardenZone{} = zone), do: Repo.delete(zone)

  @doc """
  Returns zones that are compatible with the given seed, sorted by match quality.

  A zone matches if:
  - Its allowed_types includes the seed's type (or it has no type restriction)
  - Its allowed_cycles includes the seed's cycle (or it has no cycle restriction)
  - Its sun_exposures includes the seed's sun_requirement (or it has no sun restriction)

  Zones with more matching criteria appear first (best match).
  """
  def recommend_zones(user_id, seed) do
    list_zones(user_id)
    |> Enum.filter(&zone_compatible?(&1, seed))
    |> Enum.sort_by(&zone_match_score(&1, seed), :desc)
  end

  @doc """
  Parses a comma-separated string field into a list of trimmed strings.
  Returns [] for nil or empty string.
  """
  def parse_csv_field(nil), do: []
  def parse_csv_field(""), do: []

  def parse_csv_field(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # A zone is compatible if each non-empty constraint includes the seed's attribute.
  defp zone_compatible?(zone, seed) do
    type_ok?(zone.allowed_types, seed.type) and
      cycle_ok?(zone.allowed_cycles, seed.cycle) and
      sun_ok?(zone.sun_exposures, seed.sun_requirement)
  end

  defp type_ok?(allowed, value), do: field_matches?(allowed, value)
  defp cycle_ok?(allowed, value), do: field_matches?(allowed, value)
  defp sun_ok?(allowed, value), do: field_matches?(allowed, value)

  # An empty/nil constraint matches anything; a non-empty constraint must contain the value.
  defp field_matches?(nil, _value), do: true
  defp field_matches?("", _value), do: true
  defp field_matches?(_allowed, nil), do: true
  defp field_matches?(_allowed, ""), do: true

  defp field_matches?(allowed, value) do
    allowed |> parse_csv_field() |> Enum.member?(value)
  end

  # Higher score = better match (more specific constraints that still match).
  defp zone_match_score(zone, seed) do
    [
      {zone.allowed_types, seed.type},
      {zone.allowed_cycles, seed.cycle},
      {zone.sun_exposures, seed.sun_requirement}
    ]
    |> Enum.count(fn {allowed, value} ->
      not is_nil(allowed) and allowed != "" and
        not is_nil(value) and value != "" and
        field_matches?(allowed, value)
    end)
  end
end
