defmodule BackyardGarden.PlantingsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Plantings
  alias BackyardGarden.Plantings.Planting
  alias BackyardGarden.Seeds
  alias BackyardGarden.Test.Fixtures

  defp seed_fixture(attrs \\ %{}) do
    user = Fixtures.user_fixture()

    defaults = %{
      "name" => "Test Seed",
      "brand" => "Metchosin Farm",
      "type" => "Herb",
      "cycle" => "Annual"
    }

    merged = Map.merge(defaults, Map.new(attrs, fn {k, v} -> {to_string(k), v} end))
    {:ok, seed} = Seeds.create_seed_for_user(user.id, merged)
    seed
  end

  defp planting_fixture(seed, attrs \\ %{}) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  describe "list_plantings/1" do
    test "returns all plantings for a user" do
      user = Fixtures.user_fixture()
      seed = seed_fixture()
      planting_fixture(seed, %{user_id: user.id})
      assert length(Plantings.list_plantings(user.id)) == 1
    end
  end

  describe "list_plantings_by_status/2" do
    test "returns only plantings with the given status for a user" do
      user = Fixtures.user_fixture()
      seed = seed_fixture()
      planting_fixture(seed, %{user_id: user.id, status: "planned"})
      planting_fixture(seed, %{user_id: user.id, status: "planted"})
      planned = Plantings.list_plantings_by_status(user.id, "planned")
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

      assert {:error, changeset} =
               Plantings.create_planting(%{seed_id: seed.id, status: "invalid"})

      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "update_planting/2" do
    test "updates planting status" do
      seed = seed_fixture()
      planting = planting_fixture(seed)

      assert {:ok, updated} =
               Plantings.update_planting(planting, %{
                 status: "planted",
                 planted_at: ~D[2026-03-27]
               })

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

  describe "list_plantings_for_month/2" do
    test "returns plantings planted in the given month" do
      user = Fixtures.user_fixture()
      seed = seed_fixture()
      planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-04-15]})
      planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-03-10]})
      april = ~D[2026-04-01]
      results = Plantings.list_plantings_for_month(user.id, april)
      assert length(results) == 1
      assert hd(results).planted_at == ~D[2026-04-15]
    end

    test "returns plantings with harvest due in the given month" do
      user = Fixtures.user_fixture()
      seed = seed_fixture(%{maturity_days: 50})
      # planted March 15 + 50 days = May 4 → harvest due in May
      planting_fixture(seed, %{user_id: user.id, status: "planted", planted_at: ~D[2026-03-15]})
      may = ~D[2026-05-01]
      results = Plantings.list_plantings_for_month(user.id, may)
      assert length(results) == 1
    end
  end

  describe "user scoping" do
    test "list_plantings/1 returns only user's plantings" do
      user_a = Fixtures.user_fixture()
      user_b = Fixtures.user_fixture()
      seed = seed_fixture()

      {:ok, planting_a} =
        Plantings.create_planting(%{seed_id: seed.id, user_id: user_a.id, status: "planted"})

      {:ok, _planting_b} =
        Plantings.create_planting(%{seed_id: seed.id, user_id: user_b.id, status: "planted"})

      result = Plantings.list_plantings(user_a.id)
      assert length(result) == 1
      assert hd(result).id == planting_a.id
    end

    test "list_plantings_by_status/2 scopes to user" do
      user_a = Fixtures.user_fixture()
      user_b = Fixtures.user_fixture()
      seed = seed_fixture()

      {:ok, planting_a} =
        Plantings.create_planting(%{seed_id: seed.id, user_id: user_a.id, status: "planted"})

      {:ok, _} =
        Plantings.create_planting(%{seed_id: seed.id, user_id: user_b.id, status: "planted"})

      result = Plantings.list_plantings_by_status(user_a.id, "planted")
      assert length(result) == 1
      assert hd(result).id == planting_a.id
    end
  end
end
