defmodule BackyardGarden.Weather.Client do
  @moduledoc "HTTP client for the OpenWeatherMap API."

  @doc """
  Fetches current conditions and a 3-day forecast for `city`.

  Returns `{:ok, weather_map}` or `{:error, reason}`.

  The weather map has the shape:
      %{
        city: String.t(),
        temp: float(),
        feels_like: float(),
        condition: String.t(),
        description: String.t(),
        icon: String.t(),
        forecast: [%{date: Date.t(), min_temp: float(), condition: String.t()}]
      }
  """
  def fetch_weather(city) do
    with {:ok, current} <- fetch_current(city),
         {:ok, forecast} <- fetch_forecast(city) do
      {:ok, Map.put(current, :forecast, forecast)}
    end
  end

  # --- private ---

  defp fetch_current(city) do
    case do_get("/data/2.5/weather", q: city) do
      {:ok, body} -> {:ok, parse_current(body)}
      error -> error
    end
  end

  defp fetch_forecast(city) do
    # cnt: 24 entries covers 3 days at 3-hour intervals
    case do_get("/data/2.5/forecast", q: city, cnt: 24) do
      {:ok, body} -> {:ok, parse_forecast(body)}
      error -> error
    end
  end

  defp do_get(path, params) do
    config = Application.get_env(:backyard_garden, :weather, [])
    base_url = Keyword.get(config, :base_url, "https://api.openweathermap.org")
    api_key = Keyword.get(config, :api_key, "")
    extra_opts = Keyword.get(config, :req_options, [])

    opts =
      [
        url: base_url <> path,
        params: [{:appid, api_key}, {:units, "metric"} | params]
      ] ++ extra_opts

    case Req.get(opts) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:error, :city_not_found}
      {:ok, %{status: 401}} -> {:error, :invalid_api_key}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_current(body) do
    %{
      city: body["name"],
      temp: get_in(body, ["main", "temp"]),
      feels_like: get_in(body, ["main", "feels_like"]),
      condition: get_in(body, ["weather", Access.at(0), "main"]),
      description: get_in(body, ["weather", Access.at(0), "description"]),
      icon: get_in(body, ["weather", Access.at(0), "icon"])
    }
  end

  # Group 3-hour entries by date, take the minimum temp_min per day.
  defp parse_forecast(body) do
    body["list"]
    |> Enum.group_by(fn entry ->
      entry["dt_txt"] |> String.split(" ") |> List.first() |> Date.from_iso8601!()
    end)
    |> Map.to_list()
    |> Enum.sort_by(&elem(&1, 0), Date)
    |> Enum.take(3)
    |> Enum.map(fn {date, entries} ->
      min_entry = Enum.min_by(entries, &get_in(&1, ["main", "temp_min"]))

      %{
        date: date,
        min_temp: get_in(min_entry, ["main", "temp_min"]),
        condition: get_in(hd(entries), ["weather", Access.at(0), "main"])
      }
    end)
  end
end
