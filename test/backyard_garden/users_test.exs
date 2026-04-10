defmodule BackyardGarden.UsersTest do
  use BackyardGarden.DataCase

  import Ecto.Query

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

  describe "prowl_api_key encryption" do
    test "prowl_api_key is stored encrypted and decrypts on read" do
      {:ok, user} =
        Users.create_user(%{
          "email" => "enc_test@example.com",
          "prowl_api_key" => "secret-key-123"
        })

      raw =
        BackyardGarden.Repo.one!(
          from u in "users",
            where: u.id == ^user.id,
            select: u.prowl_api_key_enc
        )

      assert is_binary(raw)
      refute raw == "secret-key-123"
      assert user.prowl_api_key == "secret-key-123"
    end
  end

  describe "upsert_from_auth0/1" do
    test "creates a new user from Auth0 credentials" do
      auth = %{
        uid: "auth0|abc123",
        info: %{email: "new@example.com", name: "New User"}
      }

      {:ok, user} = Users.upsert_from_auth0(auth)

      assert user.auth0_id == "auth0|abc123"
      assert user.email == "new@example.com"
      assert user.name == "New User"
    end

    test "updates name if user with same auth0_id already exists" do
      auth = %{uid: "auth0|existing", info: %{email: "existing@example.com", name: "Old Name"}}
      {:ok, _} = Users.upsert_from_auth0(auth)

      auth2 = %{uid: "auth0|existing", info: %{email: "existing@example.com", name: "New Name"}}
      {:ok, user} = Users.upsert_from_auth0(auth2)

      assert user.name == "New Name"
      assert BackyardGarden.Repo.aggregate(BackyardGarden.Users.User, :count, :id) == 1
    end

    test "links auth0_id to an existing account matched by email" do
      # Simulates a user created before Auth0 was added (no auth0_id).
      {:ok, existing} = Users.create_user(%{"email" => "preexisting@example.com", "name" => "Old"})
      assert existing.auth0_id == nil

      auth = %{uid: "auth0|newid", info: %{email: "preexisting@example.com", name: "Updated"}}
      {:ok, linked} = Users.upsert_from_auth0(auth)

      # Same DB row — no duplicate created.
      assert linked.id == existing.id
      assert linked.auth0_id == "auth0|newid"
      assert linked.name == "Updated"
      assert BackyardGarden.Repo.aggregate(BackyardGarden.Users.User, :count, :id) == 1
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
