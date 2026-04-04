defmodule BackyardGardenWeb.Dashboard.IndexLive do
  @moduledoc "Dashboard page — plant-now list, recently planted, upcoming schedule, and weather."

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.{Dashboard, Weather}
  alias BackyardGarden.Weather.Tips

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> load_dashboard()
     |> load_weather()}
  end

  defp load_dashboard(socket) do
    socket
    |> assign(:plant_now, Dashboard.plant_now_seeds())
    |> assign(:recently_planted, Dashboard.recently_planted())
    |> assign(:upcoming, Dashboard.upcoming_schedule())
  end

  defp load_weather(socket) do
    location = Application.get_env(:backyard_garden, :default_location, "Victoria, BC")

    case Weather.get_weather(location) do
      {:ok, weather} ->
        has_planted = socket.assigns.recently_planted != []
        tips = Tips.generate(weather, has_planted)

        socket
        |> assign(:weather, weather)
        |> assign(:weather_tips, tips)

      {:error, _reason} ->
        socket
        |> assign(:weather, nil)
        |> assign(:weather_tips, [])
    end
  end
end
