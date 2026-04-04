defmodule BackyardGardenWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use BackyardGardenWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  defp nav_link(assigns) do
    active =
      String.starts_with?(assigns.current_path, assigns.href) and
        ((assigns.href == "/" and assigns.current_path == "/") or assigns.href != "/")

    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      aria-current={if @active, do: "page", else: false}
      class={[
        "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
        if(@active,
          do: "bg-white/10 text-white font-semibold",
          else: "text-[#95d5b2] hover:text-white hover:bg-white/5"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Renders a color-coded pill badge for a seed type.

  ## Examples

      <Layouts.type_badge type="Vegetable" />
      <Layouts.type_badge type={@seed.type} />

  """
  attr :type, :string, required: true

  def type_badge(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium px-2.5 py-0.5 rounded-full",
      type_badge_classes(@type)
    ]}>
      {@type}
    </span>
    """
  end

  defp type_badge_classes("Vegetable"), do: "text-[#16a34a] bg-[#dcfce7]"
  defp type_badge_classes("Herb"), do: "text-[#7c3aed] bg-[#ede9fe]"
  defp type_badge_classes("Flower"), do: "text-[#d97706] bg-[#fef3c7]"
  defp type_badge_classes(_), do: "text-[#db2777] bg-[#fce7f3]"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
