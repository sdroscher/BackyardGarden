defmodule BackyardGarden.GardenZones do
  @moduledoc """
  Context for managing garden zones and zone recommendations.
  """

  import Ecto.Query
  alias BackyardGarden.Repo
  alias BackyardGarden.GardenZones.GardenZone

  @doc "Returns all zones ordered by name."
  def list_zones do
    GardenZone
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
end
