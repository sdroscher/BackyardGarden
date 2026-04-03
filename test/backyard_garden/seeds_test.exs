defmodule BackyardGarden.SeedsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Seeds

  defp seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  describe "list_seeds/1" do
    test "returns all seeds ordered by name when no filters" do
      seed_fixture(%{name: "Zucchini", type: "Vegetable"})
      seed_fixture(%{name: "Basil"})
      seeds = Seeds.list_seeds(%{})
      assert Enum.map(seeds, & &1.name) == ["Basil", "Zucchini"]
    end

    test "filters by type" do
      seed_fixture(%{name: "Basil", type: "Herb"})
      seed_fixture(%{name: "Carrots", type: "Vegetable"})
      seeds = Seeds.list_seeds(%{type: "Herb"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Basil"
    end

    test "filters by brand" do
      seed_fixture(%{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(%{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(%{brand: "West Coast Seeds"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "filters by cycle" do
      seed_fixture(%{name: "Basil", cycle: "Annual"})
      seed_fixture(%{name: "Echinacea", cycle: "Perennial"})
      seeds = Seeds.list_seeds(%{cycle: "Perennial"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Echinacea"
    end

    test "searches by name (case-insensitive)" do
      seed_fixture(%{name: "Purple Basil"})
      seed_fixture(%{name: "Carrots"})
      seeds = Seeds.list_seeds(%{search: "basil"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Purple Basil"
    end

    test "searches by brand" do
      seed_fixture(%{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(%{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(%{search: "west coast"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "empty string filters are ignored" do
      seed_fixture(%{name: "Basil"})
      seed_fixture(%{name: "Carrots"})
      seeds = Seeds.list_seeds(%{type: "", brand: "", cycle: "", search: ""})
      assert length(seeds) == 2
    end

    test "filters by planting_method" do
      seed_fixture(%{name: "Basil", planting_method: "Seedlings"})
      seed_fixture(%{name: "Carrots", planting_method: "Direct Sow"})
      seeds = Seeds.list_seeds(%{planting_method: "Seedlings"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Basil"
    end

    test "filters by sun_requirement" do
      seed_fixture(%{name: "Basil", sun_requirement: "full_sun"})
      seed_fixture(%{name: "Spinach", sun_requirement: "partial_sun"})
      seeds = Seeds.list_seeds(%{sun_requirement: "partial_sun"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Spinach"
    end

    test "sorts by name ascending by default" do
      seed_fixture(%{name: "Zucchini"})
      seed_fixture(%{name: "Basil"})
      seeds = Seeds.list_seeds(%{})
      assert hd(seeds).name == "Basil"
    end

    test "sorts by name descending" do
      seed_fixture(%{name: "Zucchini"})
      seed_fixture(%{name: "Basil"})
      seeds = Seeds.list_seeds(%{sort_field: "name", sort_dir: :desc})
      assert hd(seeds).name == "Zucchini"
    end

    test "sorts by type ascending" do
      seed_fixture(%{name: "Zucchini", type: "Vegetable"})
      seed_fixture(%{name: "Basil", type: "Herb"})
      seeds = Seeds.list_seeds(%{sort_field: "type", sort_dir: :asc})
      assert hd(seeds).type == "Herb"
    end

    test "unknown sort_field falls back to name sort" do
      seed_fixture(%{name: "Zucchini"})
      seed_fixture(%{name: "Basil"})
      seeds = Seeds.list_seeds(%{sort_field: "nonexistent", sort_dir: :asc})
      assert hd(seeds).name == "Basil"
    end
  end

  describe "get_seed!/1" do
    test "returns the seed with given id" do
      seed = seed_fixture()
      assert Seeds.get_seed!(seed.id).name == seed.name
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Seeds.get_seed!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_types/0" do
    test "returns distinct non-nil types sorted" do
      seed_fixture(%{type: "Vegetable"})
      seed_fixture(%{type: "Herb"})
      seed_fixture(%{type: "Herb"})
      assert Seeds.list_types() == ["Herb", "Vegetable"]
    end
  end

  describe "list_brands/0" do
    test "returns distinct non-nil brands sorted" do
      seed_fixture(%{brand: "West Coast Seeds"})
      seed_fixture(%{brand: "Metchosin Farm"})
      assert Seeds.list_brands() == ["Metchosin Farm", "West Coast Seeds"]
    end
  end

  describe "list_cycles/0" do
    test "returns distinct non-nil cycles sorted" do
      seed_fixture(%{cycle: "Perennial"})
      seed_fixture(%{cycle: "Annual"})
      assert Seeds.list_cycles() == ["Annual", "Perennial"]
    end
  end

  describe "list_planting_methods/0" do
    test "returns distinct non-nil planting methods sorted" do
      seed_fixture(%{planting_method: "Direct Sow"})
      seed_fixture(%{planting_method: "Seedlings"})
      seed_fixture(%{planting_method: "Seedlings"})
      assert Seeds.list_planting_methods() == ["Direct Sow", "Seedlings"]
    end
  end

  describe "list_sun_requirements/0" do
    test "returns distinct non-nil sun requirements sorted" do
      seed_fixture(%{sun_requirement: "full_sun"})
      seed_fixture(%{sun_requirement: "partial_sun"})
      assert Seeds.list_sun_requirements() == ["full_sun", "partial_sun"]
    end
  end

  describe "create_seed/1" do
    test "creates a seed with valid attrs" do
      attrs = %{name: "Basil", brand: "Metchosin Farm", type: "Herb", cycle: "Annual"}
      assert {:ok, %{name: "Basil"}} = Seeds.create_seed(attrs)
    end

    test "returns error changeset when name is missing" do
      assert {:error, changeset} = Seeds.create_seed(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_seed/2" do
    test "updates a seed with valid attrs" do
      seed = seed_fixture(%{sun_requirement: nil})
      assert {:ok, updated} = Seeds.update_seed(seed, %{sun_requirement: "full_sun"})
      assert updated.sun_requirement == "full_sun"
    end

    test "updates source_url" do
      seed = seed_fixture()
      assert {:ok, updated} = Seeds.update_seed(seed, %{source_url: "https://example.com"})
      assert updated.source_url == "https://example.com"
    end

    test "returns error changeset when name is set to blank" do
      seed = seed_fixture()
      assert {:error, changeset} = Seeds.update_seed(seed, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
