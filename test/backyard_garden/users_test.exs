defmodule BackyardGarden.UsersTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Users

  describe "create_user/1" do
    test "creates a user with email and returns ok" do
      attrs = %{"email" => "simon@example.com", "name" => "Simon"}
      assert {:ok, user} = Users.create_user(attrs)
      assert user.email == "simon@example.com"
      assert user.name == "Simon"
      assert user.timezone == "America/Vancouver"
    end

    test "requires email" do
      attrs = %{"name" => "Simon"}
      assert {:error, changeset} = Users.create_user(attrs)
      assert errors_on(changeset)[:email]
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email if exists" do
      user = user_fixture(email: "test@example.com")
      assert Users.get_user_by_email("test@example.com").id == user.id
    end

    test "returns nil if user does not exist" do
      assert Users.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "update_user/2" do
    test "updates user prowl_api_key" do
      user = user_fixture()
      assert {:ok, updated} = Users.update_user(user, %{"prowl_api_key" => "testkey123"})
      assert updated.prowl_api_key == "testkey123"
    end
  end

  # Fixture helper
  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      %{
        "email" => "test#{System.unique_integer()}@example.com"
      }
      |> Map.merge(Map.new(attrs, fn {k, v} -> {to_string(k), v} end))
      |> Users.create_user()

    user
  end
end
