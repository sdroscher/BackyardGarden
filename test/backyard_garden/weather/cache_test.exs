defmodule BackyardGarden.Weather.CacheTest do
  use ExUnit.Case, async: false

  alias BackyardGarden.Weather.Cache

  setup do
    Cache.clear()
    :ok
  end

  test "returns :miss for a city not yet cached" do
    assert :miss = Cache.get("Victoria")
  end

  test "returns {:ok, data} after put" do
    data = %{city: "Victoria", temp: 12.5}
    Cache.put("Victoria", data)

    assert {:ok, ^data} = Cache.get("Victoria")
  end

  test "clear/0 removes all entries" do
    Cache.put("Victoria", %{temp: 12.5})
    Cache.put("Vancouver", %{temp: 10.0})

    Cache.clear()

    assert :miss = Cache.get("Victoria")
    assert :miss = Cache.get("Vancouver")
  end

  test "returns :miss after TTL has expired" do
    data = %{city: "Victoria", temp: 12.5}
    # Store with a timestamp far in the past to simulate expiry
    :ets.insert(
      :weather_cache,
      {"Victoria", data, System.monotonic_time(:millisecond) - :timer.hours(2)}
    )

    assert :miss = Cache.get("Victoria")
  end
end
