defmodule BackyardGarden.WeatherClientStub do
  @moduledoc "Deterministic stub for Weather.Client used in tests."

  def fetch_weather("Victoria, BC") do
    {:ok,
     %{
       city: "Victoria",
       temp: 12.5,
       feels_like: 10.0,
       condition: "Clear",
       description: "clear sky",
       icon: "01d",
       forecast: [
         %{date: ~D[2026-04-04], min_temp: 6.0, condition: "Clouds"},
         %{date: ~D[2026-04-05], min_temp: 4.0, condition: "Clear"},
         %{date: ~D[2026-04-06], min_temp: 8.0, condition: "Rain"}
       ]
     }}
  end

  # Reserved for dashboard LiveView tests that exercise the frost-warning tip display path
  def fetch_weather("FrostCity") do
    {:ok,
     %{
       city: "FrostCity",
       temp: 2.0,
       feels_like: 0.0,
       condition: "Clear",
       description: "clear sky",
       icon: "01n",
       forecast: [
         %{date: ~D[2026-04-04], min_temp: -1.0, condition: "Clear"},
         %{date: ~D[2026-04-05], min_temp: -2.0, condition: "Clear"},
         %{date: ~D[2026-04-06], min_temp: 0.0, condition: "Clear"}
       ]
     }}
  end

  def fetch_weather(_city), do: {:error, :city_not_found}
end
