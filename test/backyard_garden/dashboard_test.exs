defmodule BackyardGarden.DashboardTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Dashboard
  alias BackyardGarden.{Seeds, Plantings}

  defp seed_fixture(attrs) do
    defaults = %{
      name: "Test Seed",
      type: "Vegetable",
      cycle: "Annual",
      ideal_planting_time: "spring",
      maturity_days: 50
    }

    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  describe "plant_now_seeds/1" do
    test "returns seeds whose window includes the given month" do
      seed_fixture(%{name: "Spinach", ideal_planting_time: "spring"})

      # spring = {3, 5}, April is month 4
      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      assert "Spinach" in names
    end

    test "excludes seeds already planted" do
      seed = seed_fixture(%{name: "Planted Seed", ideal_planting_time: "spring"})
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Planted Seed" in names
    end

    test "excludes seeds already planned" do
      seed = seed_fixture(%{name: "Planned Seed", ideal_planting_time: "spring"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Planned Seed" in names
    end

    test "excludes seeds with no parseable planting time" do
      seed_fixture(%{name: "Unknown", ideal_planting_time: nil})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Unknown" in names
    end

    test "excludes seeds out of their planting window" do
      seed_fixture(%{name: "Summer Seed", ideal_planting_time: "summer"})

      # summer = {6, 8}, April is outside
      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Summer Seed" in names
    end
  end

  describe "recently_planted/1" do
    test "returns planted plantings in descending planted_at order" do
      seed1 = seed_fixture(%{name: "Spinach"})
      seed2 = seed_fixture(%{name: "Chard"})
      planting_fixture(seed1, %{status: "planted", planted_at: ~D[2026-03-20]})
      planting_fixture(seed2, %{status: "planted", planted_at: ~D[2026-03-27]})

      [first | _] = Dashboard.recently_planted(5)
      assert first.seed.name == "Chard"
    end

    test "does not return planned or harvested plantings" do
      seed = seed_fixture(%{name: "Planned"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.recently_planted(5)
      names = Enum.map(result, & &1.seed.name)
      refute "Planned" in names
    end

    test "respects the limit" do
      seed = seed_fixture(%{name: "Repeated"})

      for i <- 1..10 do
        planting_fixture(seed, %{status: "planted", planted_at: Date.new!(2026, 3, i)})
      end

      assert length(Dashboard.recently_planted(3)) == 3
    end
  end

  describe "upcoming_schedule/2" do
    test "returns seeds with windows opening in the future within days_ahead" do
      # May = month 5; today is April 3, so May 1 is 28 days away
      seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      assert "May Seed" in names
    end

    test "does not include seeds whose window opens today or in the past" do
      # April window opened April 1; today is April 3 — already in Plant Now
      seed_fixture(%{name: "April Seed", ideal_planting_time: "april"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "April Seed" in names
    end

    test "does not include seeds beyond days_ahead" do
      # August 1 is 120 days from April 3 — beyond 60
      seed_fixture(%{name: "Far Future Seed", ideal_planting_time: "august"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "Far Future Seed" in names
    end

    test "excludes seeds already planted or planned" do
      seed = seed_fixture(%{name: "Already Planned May", ideal_planting_time: "may"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "Already Planned May" in names
    end

    test "returns results sorted by window open date" do
      seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})
      seed_fixture(%{name: "June Seed", ideal_planting_time: "june"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 90)
      names = Enum.map(result, fn {s, _} -> s.name end)

      may_idx = Enum.find_index(names, &(&1 == "May Seed"))
      june_idx = Enum.find_index(names, &(&1 == "June Seed"))

      assert may_idx < june_idx
    end

    test "includes the window open date in each result" do
      seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      {_seed, open_date} = Enum.find(result, fn {s, _} -> s.name == "May Seed" end)

      assert open_date == ~D[2026-05-01]
    end
  end
end
