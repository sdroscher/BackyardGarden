defmodule BackyardGarden.WeatherTest do
  use ExUnit.Case, async: false

  alias BackyardGarden.Weather
  alias BackyardGarden.Weather.Cache

  setup do
    Cache.clear()
    :ok
  end

  test "returns weather data for a known city" do
    assert {:ok, weather} = Weather.get_weather("Victoria, BC")

    assert weather.city == "Victoria"
    assert weather.temp == 12.5
    assert weather.condition == "Clear"
    assert length(weather.forecast) == 3
  end

  test "returns {:error, :city_not_found} for an unknown city" do
    assert {:error, :city_not_found} = Weather.get_weather("Atlantis")
  end

  test "returns {:error, :invalid_city} for nil or empty city" do
    assert {:error, :invalid_city} = Weather.get_weather(nil)
    assert {:error, :invalid_city} = Weather.get_weather("")
  end

  test "caches the result so the client is not called twice" do
    {:ok, first} = Weather.get_weather("Victoria, BC")

    # Mutate cache directly to confirm second call hits cache, not stub
    Cache.put("Victoria, BC", %{first | temp: 99.9})
    {:ok, second} = Weather.get_weather("Victoria, BC")

    assert second.temp == 99.9
  end
end
