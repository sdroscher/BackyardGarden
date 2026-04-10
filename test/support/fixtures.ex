defmodule BackyardGarden.Test.Fixtures do
  @moduledoc "Shared test fixture helpers for creating database records."

  alias BackyardGarden.Users
  alias BackyardGarden.Seeds

  @doc "Creates a user with a unique email. Accepts string-keyed attrs to override defaults."
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      %{"email" => "user#{System.unique_integer()}@example.com"}
      |> Map.merge(Map.new(attrs, fn {k, v} -> {to_string(k), v} end))
      |> Users.create_user()

    user
  end

  @doc "Creates a seed with default values. Accepts atom-keyed attrs to override defaults."
  def seed_fixture(attrs \\ %{}) do
    defaults = %{name: "Test Seed #{System.unique_integer()}", type: "Vegetable", cycle: "Annual"}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end
end
