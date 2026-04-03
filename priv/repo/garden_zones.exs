# priv/repo/garden_zones.exs
# Run with: mix run priv/repo/garden_zones.exs
#
# Idempotent: skips zones that already exist (matched by name).

alias BackyardGarden.Repo
alias BackyardGarden.GardenZones.GardenZone
import Ecto.Query

zones = [
  %{
    name: "Sunny Raised Planters",
    description: "South-facing raised beds — full sun all day",
    sun_exposures: "full_sun",
    allowed_types: "Vegetable",
    allowed_cycles: "Annual"
  },
  %{
    name: "Herb Boxes",
    description: "Raised boxes along the fence — variable sun depending on position",
    sun_exposures: "full_sun,partial_sun,shade_tolerant",
    allowed_types: "Herb",
    allowed_cycles: ""
  },
  %{
    name: "Back Garden",
    description: "Open garden bed — full sun to part shade, ideal for perennials",
    sun_exposures: "full_sun,partial_sun,shade_tolerant",
    allowed_types: "",
    allowed_cycles: "Perennial,Biennial"
  }
]

existing_names =
  GardenZone
  |> select([z], z.name)
  |> Repo.all()
  |> MapSet.new()

Enum.each(zones, fn attrs ->
  if MapSet.member?(existing_names, attrs.name) do
    IO.puts("Skipping (already exists): #{attrs.name}")
  else
    Repo.insert!(%GardenZone{
      id: Ecto.UUID.generate(),
      name: attrs.name,
      description: attrs.description,
      sun_exposures: attrs.sun_exposures,
      allowed_types: attrs.allowed_types,
      allowed_cycles: attrs.allowed_cycles
    })

    IO.puts("Created: #{attrs.name}")
  end
end)
