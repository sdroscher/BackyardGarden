defmodule BackyardGarden.Users do
  @moduledoc "User context — CRUD operations and queries."

  alias BackyardGarden.Repo
  alias BackyardGarden.Users.User

  @doc "Create a user from attributes."
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Get user by email, or nil if not found."
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc "Get user by id, or nil if not found."
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc "Update a user from attributes."
  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc "List all users."
  def list_users do
    Repo.all(User)
  end

  @doc """
  Creates or updates a user based on their Auth0 credentials.
  Matches on auth0_id; on first login the user is created with email and name from Auth0.
  """
  def upsert_from_auth0(%{uid: auth0_id, info: %{email: email, name: name}}) do
    case Repo.get_by(User, auth0_id: auth0_id) do
      nil ->
        create_user(%{
          "auth0_id" => auth0_id,
          "email" => email,
          "name" => name
        })

      user ->
        update_user(user, %{"name" => name})
    end
  end
end
