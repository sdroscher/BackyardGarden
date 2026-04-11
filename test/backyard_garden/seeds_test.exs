defmodule BackyardGarden.SeedsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Seeds
  alias BackyardGarden.Test.Fixtures

  setup do
    user = Fixtures.user_fixture()
    %{user: user}
  end

  defp seed_fixture(user, attrs \\ %{}) do
    defaults = %{
      "name" => "Test Seed",
      "brand" => "Metchosin Farm",
      "type" => "Herb",
      "cycle" => "Annual"
    }

    merged =
      Map.merge(defaults, Map.new(attrs, fn {k, v} -> {to_string(k), v} end))

    {:ok, seed} = Seeds.create_seed_for_user(user.id, merged)
    seed
  end

  describe "list_seeds/2" do
    test "returns all seeds ordered by name when no filters", %{user: user} do
      seed_fixture(user, %{name: "Zucchini", type: "Vegetable"})
      seed_fixture(user, %{name: "Basil"})
      seeds = Seeds.list_seeds(user.id, %{})
      assert Enum.map(seeds, & &1.name) == ["Basil", "Zucchini"]
    end

    test "filters by type", %{user: user} do
      seed_fixture(user, %{name: "Basil", type: "Herb"})
      seed_fixture(user, %{name: "Carrots", type: "Vegetable"})
      seeds = Seeds.list_seeds(user.id, %{type: "Herb"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Basil"
    end

    test "filters by brand", %{user: user} do
      seed_fixture(user, %{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(user, %{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(user.id, %{brand: "West Coast Seeds"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "filters by cycle", %{user: user} do
      seed_fixture(user, %{name: "Basil", cycle: "Annual"})
      seed_fixture(user, %{name: "Echinacea", cycle: "Perennial"})
      seeds = Seeds.list_seeds(user.id, %{cycle: "Perennial"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Echinacea"
    end

    test "searches by name (case-insensitive)", %{user: user} do
      seed_fixture(user, %{name: "Purple Basil"})
      seed_fixture(user, %{name: "Carrots"})
      seeds = Seeds.list_seeds(user.id, %{search: "basil"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Purple Basil"
    end

    test "searches by brand", %{user: user} do
      seed_fixture(user, %{name: "Basil", brand: "Metchosin Farm"})
      seed_fixture(user, %{name: "Carrots", brand: "West Coast Seeds"})
      seeds = Seeds.list_seeds(user.id, %{search: "west coast"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Carrots"
    end

    test "empty string filters are ignored", %{user: user} do
      seed_fixture(user, %{name: "Basil"})
      seed_fixture(user, %{name: "Carrots"})
      seeds = Seeds.list_seeds(user.id, %{type: "", brand: "", cycle: "", search: ""})
      assert length(seeds) == 2
    end

    test "filters by planting_method", %{user: user} do
      seed_fixture(user, %{name: "Basil", planting_method: "Seedlings"})
      seed_fixture(user, %{name: "Carrots", planting_method: "Direct Sow"})
      seeds = Seeds.list_seeds(user.id, %{planting_method: "Seedlings"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Basil"
    end

    test "filters by sun_requirement", %{user: user} do
      seed_fixture(user, %{name: "Basil", sun_requirement: "full_sun"})
      seed_fixture(user, %{name: "Spinach", sun_requirement: "partial_sun"})
      seeds = Seeds.list_seeds(user.id, %{sun_requirement: "partial_sun"})
      assert length(seeds) == 1
      assert hd(seeds).name == "Spinach"
    end

    test "sorts by name ascending by default", %{user: user} do
      seed_fixture(user, %{name: "Zucchini"})
      seed_fixture(user, %{name: "Basil"})
      seeds = Seeds.list_seeds(user.id, %{})
      assert hd(seeds).name == "Basil"
    end

    test "sorts by name descending", %{user: user} do
      seed_fixture(user, %{name: "Zucchini"})
      seed_fixture(user, %{name: "Basil"})
      seeds = Seeds.list_seeds(user.id, %{sort_field: "name", sort_dir: :desc})
      assert hd(seeds).name == "Zucchini"
    end

    test "sorts by type ascending", %{user: user} do
      seed_fixture(user, %{name: "Zucchini", type: "Vegetable"})
      seed_fixture(user, %{name: "Basil", type: "Herb"})
      seeds = Seeds.list_seeds(user.id, %{sort_field: "type", sort_dir: :asc})
      assert hd(seeds).type == "Herb"
    end

    test "unknown sort_field falls back to name sort", %{user: user} do
      seed_fixture(user, %{name: "Zucchini"})
      seed_fixture(user, %{name: "Basil"})
      seeds = Seeds.list_seeds(user.id, %{sort_field: "nonexistent", sort_dir: :asc})
      assert hd(seeds).name == "Basil"
    end

    test "only returns seeds for the given user", %{user: user} do
      other_user = Fixtures.user_fixture()
      seed_fixture(user, %{name: "My Basil"})
      seed_fixture(other_user, %{name: "Their Basil"})
      seeds = Seeds.list_seeds(user.id, %{})
      names = Enum.map(seeds, & &1.name)
      assert "My Basil" in names
      refute "Their Basil" in names
    end
  end

  describe "get_seed!/1" do
    test "returns the seed with given id", %{user: user} do
      seed = seed_fixture(user)
      assert Seeds.get_seed!(seed.id).name == seed.name
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Seeds.get_seed!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_seed/1" do
    test "returns seed by id", %{user: user} do
      seed = seed_fixture(user)
      assert Seeds.get_seed(seed.id).id == seed.id
    end

    test "returns nil for unknown id" do
      assert is_nil(Seeds.get_seed(Ecto.UUID.generate()))
    end
  end

  describe "list_types/1" do
    test "returns distinct non-nil types sorted", %{user: user} do
      seed_fixture(user, %{type: "Vegetable"})
      seed_fixture(user, %{type: "Herb"})
      seed_fixture(user, %{type: "Herb"})
      assert Seeds.list_types(user.id) == ["Herb", "Vegetable"]
    end
  end

  describe "list_brands/1" do
    test "returns distinct non-nil brands sorted", %{user: user} do
      seed_fixture(user, %{brand: "West Coast Seeds"})
      seed_fixture(user, %{brand: "Metchosin Farm"})
      assert Seeds.list_brands(user.id) == ["Metchosin Farm", "West Coast Seeds"]
    end
  end

  describe "list_cycles/1" do
    test "returns distinct non-nil cycles sorted", %{user: user} do
      seed_fixture(user, %{cycle: "Perennial"})
      seed_fixture(user, %{cycle: "Annual"})
      assert Seeds.list_cycles(user.id) == ["Annual", "Perennial"]
    end
  end

  describe "list_planting_methods/1" do
    test "returns distinct non-nil planting methods sorted", %{user: user} do
      seed_fixture(user, %{planting_method: "Direct Sow"})
      seed_fixture(user, %{planting_method: "Seedlings"})
      seed_fixture(user, %{planting_method: "Seedlings"})
      assert Seeds.list_planting_methods(user.id) == ["Direct Sow", "Seedlings"]
    end
  end

  describe "list_sun_requirements/1" do
    test "returns distinct non-nil sun requirements sorted", %{user: user} do
      seed_fixture(user, %{sun_requirement: "full_sun"})
      seed_fixture(user, %{sun_requirement: "partial_sun"})
      assert Seeds.list_sun_requirements(user.id) == ["full_sun", "partial_sun"]
    end
  end

  describe "create_seed_for_user/2" do
    test "creates a seed with valid attrs", %{user: user} do
      attrs = %{
        "name" => "Basil",
        "brand" => "Metchosin Farm",
        "type" => "Herb",
        "cycle" => "Annual"
      }

      assert {:ok, %{name: "Basil"}} = Seeds.create_seed_for_user(user.id, attrs)
    end

    test "returns error changeset when name is missing", %{user: user} do
      assert {:error, changeset} = Seeds.create_seed_for_user(user.id, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_seed/2" do
    test "updates a seed with valid attrs", %{user: user} do
      seed = seed_fixture(user, %{sun_requirement: nil})
      assert {:ok, updated} = Seeds.update_seed(seed, %{sun_requirement: "full_sun"})
      assert updated.sun_requirement == "full_sun"
    end

    test "updates source_url", %{user: user} do
      seed = seed_fixture(user)
      assert {:ok, updated} = Seeds.update_seed(seed, %{source_url: "https://example.com"})
      assert updated.source_url == "https://example.com"
    end

    test "returns error changeset when name is set to blank", %{user: user} do
      seed = seed_fixture(user)
      assert {:error, changeset} = Seeds.update_seed(seed, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
