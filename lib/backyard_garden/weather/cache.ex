defmodule BackyardGarden.Weather.Cache do
  @moduledoc "ETS-backed GenServer cache for OpenWeatherMap responses. TTL: 1 hour."

  use GenServer

  @table :weather_cache
  @ttl_ms :timer.hours(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns `{:ok, data}` if city is cached and fresh, `:miss` otherwise."
  def get(city) do
    case :ets.lookup(@table, city) do
      [{^city, data, stored_at}] ->
        if System.monotonic_time(:millisecond) - stored_at < @ttl_ms do
          {:ok, data}
        else
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc "Stores weather data for city."
  def put(city, data) do
    :ets.insert(@table, {city, data, System.monotonic_time(:millisecond)})
    :ok
  end

  @doc "Removes all cached entries."
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end
end
