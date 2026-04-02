defmodule BackyardGarden.PlantingsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Plantings
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Seeds

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs \\ %{}) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  describe "list_plantings/0" do
    test "returns all plantings" do
      seed = seed_fixture()
      planting_fixture(seed)
      assert length(Plantings.list_plantings()) == 1
    end
  end

  describe "list_plantings_by_status/1" do
    test "returns only plantings with the given status" do
      seed = seed_fixture()
      planting_fixture(seed, %{status: "planned"})
      planting_fixture(seed, %{status: "planted"})
      planned = Plantings.list_plantings_by_status("planned")
      assert length(planned) == 1
      assert hd(planned).status == "planned"
    end
  end

  describe "get_planting!/1" do
    test "returns planting by id" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert Plantings.get_planting!(planting.id).id == planting.id
    end

    test "raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Plantings.get_planting!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_planting/1" do
    test "creates planting with valid attrs" do
      seed = seed_fixture()
      attrs = %{seed_id: seed.id, status: "planned", planted_at: ~D[2026-03-27]}
      assert {:ok, %Planting{status: "planned"}} = Plantings.create_planting(attrs)
    end

    test "returns error changeset when seed_id is missing" do
      assert {:error, changeset} = Plantings.create_planting(%{status: "planned"})
      assert %{seed_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status is one of planned/planted/harvested" do
      seed = seed_fixture()
      assert {:error, changeset} = Plantings.create_planting(%{seed_id: seed.id, status: "invalid"})
      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "update_planting/2" do
    test "updates planting status" do
      seed = seed_fixture()
      planting = planting_fixture(seed)

      assert {:ok, updated} =
               Plantings.update_planting(planting, %{status: "planted", planted_at: ~D[2026-03-27]})

      assert updated.status == "planted"
      assert updated.planted_at == ~D[2026-03-27]
    end

    test "returns error changeset for invalid status" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert {:error, _changeset} = Plantings.update_planting(planting, %{status: "bad"})
    end
  end

  describe "delete_planting/1" do
    test "deletes the planting" do
      seed = seed_fixture()
      planting = planting_fixture(seed)
      assert {:ok, _} = Plantings.delete_planting(planting)
      assert_raise Ecto.NoResultsError, fn -> Plantings.get_planting!(planting.id) end
    end
  end

  describe "list_plantings_for_month/1" do
    test "returns plantings planted in the given month" do
      seed = seed_fixture()
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-04-15]})
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-10]})
      april = ~D[2026-04-01]
      results = Plantings.list_plantings_for_month(april)
      assert length(results) == 1
      assert hd(results).planted_at == ~D[2026-04-15]
    end

    test "returns plantings with harvest due in the given month" do
      seed = seed_fixture(%{maturity_days: 50})
      # planted March 15 + 50 days = May 4 → harvest due in May
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-15]})
      may = ~D[2026-05-01]
      results = Plantings.list_plantings_for_month(may)
      assert length(results) == 1
    end
  end
end
