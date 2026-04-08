defmodule BackyardGardenWeb.Settings.NotificationsLive do
  @moduledoc """
  Settings page for notification configuration (Prowl API key, preferences).
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Users

  @impl true
  def mount(_params, _session, socket) do
    # For now, use default user simon@droscher.com
    # In Phase 5, this will use authenticated user from session
    user = Users.get_user_by_email("simon@droscher.com") || create_default_user()
    changeset = Users.User.changeset(user, %{})

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    user = socket.assigns.user

    case Users.update_user(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "Notification settings updated!")
         |> assign(:changeset, Users.User.changeset(updated_user, %{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <h1 class="text-3xl font-semibold text-[#14532d] mb-8">Notification Settings</h1>

      <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
        <form phx-submit="save" class="space-y-6">
          <.input
            field={@changeset[:prowl_api_key]}
            label="Prowl API Key"
            type="password"
            placeholder="Paste your Prowl API key here"
          />
          <p class="text-sm text-[#6b7280]">
            Your Prowl API key is used to send notifications to your iOS device.
            <a
              href="https://www.prowlapp.com/"
              target="_blank"
              class="text-[#2d6a4f] underline"
            >
              Get your key from Prowl
            </a>
          </p>

          <.input
            field={@changeset[:notifications_enabled]}
            label="Enable Notifications"
            type="checkbox"
          />

          <div class="pt-4">
            <button
              type="submit"
              class="bg-[#2d6a4f] text-white px-4 py-2 rounded-lg hover:bg-[#1a3a2a]"
            >
              Save Settings
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp create_default_user do
    {:ok, user} =
      Users.create_user(%{
        "email" => "simon@droscher.com",
        "name" => "Simon"
      })

    user
  end
end
