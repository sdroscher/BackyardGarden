defmodule BackyardGarden.GardenZonesTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.GardenZones
  alias BackyardGarden.GardenZones.GardenZone
  alias BackyardGarden.Test.Fixtures

  defp zone_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Test Zone",
      sun_exposures: "full_sun",
      allowed_types: "Vegetable",
      allowed_cycles: "Annual"
    }

    {:ok, zone} = GardenZones.create_zone(Map.merge(defaults, attrs))
    zone
  end

  describe "list_zones/1" do
    test "returns zones for a user ordered by name" do
      user = Fixtures.user_fixture()
      zone_fixture(%{name: "Back Garden", user_id: user.id})
      zone_fixture(%{name: "Herb Boxes", user_id: user.id})
      zones = GardenZones.list_zones(user.id)
      assert Enum.map(zones, & &1.name) == ["Back Garden", "Herb Boxes"]
    end

    test "does not return another user's zones" do
      user_a = Fixtures.user_fixture()
      user_b = Fixtures.user_fixture()
      zone_fixture(%{name: "User A Zone", user_id: user_a.id})
      assert GardenZones.list_zones(user_b.id) == []
    end
  end

  describe "get_zone!/1" do
    test "returns zone by id" do
      zone = zone_fixture()
      assert GardenZones.get_zone!(zone.id).name == zone.name
    end

    test "raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        GardenZones.get_zone!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_zone/1" do
    test "creates a zone with valid attrs" do
      attrs = %{name: "Sunny Beds", sun_exposures: "full_sun"}
      assert {:ok, %GardenZone{name: "Sunny Beds"}} = GardenZones.create_zone(attrs)
    end

    test "returns error changeset when name is missing" do
      assert {:error, changeset} = GardenZones.create_zone(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_zone/2" do
    test "updates zone fields" do
      zone = zone_fixture()
      assert {:ok, updated} = GardenZones.update_zone(zone, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error changeset for blank name" do
      zone = zone_fixture()
      assert {:error, _changeset} = GardenZones.update_zone(zone, %{name: ""})
    end
  end

  describe "delete_zone/1" do
    test "deletes the zone" do
      zone = zone_fixture()
      assert {:ok, _} = GardenZones.delete_zone(zone)
      assert_raise Ecto.NoResultsError, fn -> GardenZones.get_zone!(zone.id) end
    end
  end

  describe "parse_csv_field/1" do
    test "parses comma-separated string into list" do
      assert GardenZones.parse_csv_field("full_sun,partial_sun") == ["full_sun", "partial_sun"]
    end

    test "returns empty list for nil" do
      assert GardenZones.parse_csv_field(nil) == []
    end

    test "returns empty list for empty string" do
      assert GardenZones.parse_csv_field("") == []
    end

    test "trims whitespace from values" do
      assert GardenZones.parse_csv_field("full_sun, partial_sun") == ["full_sun", "partial_sun"]
    end
  end
end
