defmodule BackyardGarden.Weather do
  @moduledoc """
  Public facade for weather data. Checks the ETS cache first;
  falls back to the configured HTTP client on a cache miss.
  """

  alias BackyardGarden.Weather.Cache

  @doc """
  Returns `{:ok, weather_map}` for `city` or `{:error, reason}`.

  The weather map has keys: `:city`, `:temp`, `:feels_like`, `:condition`,
  `:description`, `:icon`, `:forecast` (list of 3-day daily maps).
  """
  def get_weather(city) when is_binary(city) and city != "" do
    case Cache.get(city) do
      {:ok, data} ->
        {:ok, data}

      :miss ->
        case client().fetch_weather(city) do
          {:ok, data} ->
            Cache.put(city, data)
            {:ok, data}

          error ->
            error
        end
    end
  end

  def get_weather(_), do: {:error, :invalid_city}

  # Injected via config so tests never touch the real HTTP client
  defp client do
    Application.get_env(:backyard_garden, :weather_client, BackyardGarden.Weather.Client)
  end
end
