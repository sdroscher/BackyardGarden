defmodule BackyardGardenWeb.Settings.ProfileLive do
  @moduledoc """
  LiveView for user profile settings — location, timezone.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Users

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    form = to_form(Users.User.changeset(user, %{}))

    {:ok,
     socket
     |> assign(:page_title, "Profile Settings")
     |> assign(:user, user)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    user = socket.assigns.user

    case Users.update_user(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "Profile updated!")
         |> assign(:form, to_form(Users.User.changeset(updated_user, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="border-b border-[#e5e7eb] flex gap-6">
        <a
          href={~p"/settings"}
          class="pb-3 text-sm font-semibold text-[#2d6a4f] border-b-2 border-[#2d6a4f]"
        >
          Profile
        </a>
        <a
          href={~p"/settings/zones"}
          class="pb-3 text-sm font-medium text-[#6b7280] hover:text-[#374151] border-b-2 border-transparent transition-colors"
        >
          Garden Zones
        </a>
        <a
          href={~p"/settings/notifications"}
          class="pb-3 text-sm font-medium text-[#6b7280] hover:text-[#374151] border-b-2 border-transparent transition-colors"
        >
          Notifications
        </a>
      </div>

      <h1 class="text-2xl font-bold text-[#14532d]">Profile Settings</h1>

      <div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
        <div class="px-6 py-4" style="background: linear-gradient(135deg, #2d6a4f, #52b788);">
          <h2 class="text-white text-base font-bold">Your Details</h2>
        </div>
        <div class="bg-white px-6 pb-6 pt-4">
          <.form for={@form} phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} label="Name" />
            <.input field={@form[:email]} label="Email" type="email" />
            <.input
              field={@form[:location]}
              label="Location"
              placeholder="e.g. Victoria, CA"
            />
            <p class="text-sm text-[#6b7280]">
              Used for weather forecasts. Format: City, CountryCode (e.g. "Victoria, CA").
            </p>
            <.input
              field={@form[:timezone]}
              label="Timezone"
              placeholder="e.g. America/Vancouver"
            />
            <div class="pt-2">
              <button
                type="submit"
                class="bg-[#2d6a4f] text-white px-5 py-2 rounded-lg text-sm font-medium hover:bg-[#1a3a2a] transition-colors"
              >
                Save Profile
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
