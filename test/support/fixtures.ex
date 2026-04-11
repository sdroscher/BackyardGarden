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

  @doc "Creates a seed owned by `user` with default values. Accepts atom-keyed attrs to override defaults."
  def seed_fixture(user, attrs \\ %{}) do
    defaults = %{name: "Test Seed #{System.unique_integer()}", type: "Vegetable", cycle: "Annual"}

    merged =
      Map.merge(defaults, attrs)
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    {:ok, seed} = Seeds.create_seed_for_user(user.id, merged)
    seed
  end
end
