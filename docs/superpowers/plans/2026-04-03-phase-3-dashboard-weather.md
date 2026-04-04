# Phase 3: Dashboard & Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time dashboard at `/` showing plant-now seeds, recently planted items, upcoming planting schedule, and an OpenWeatherMap weather widget with weather-aware planting tips.

**Architecture:** A new `Dashboard.IndexLive` LiveView replaces the static `PageController` home page. Domain logic lives in three focused modules: `Weather.Client` (Req HTTP calls), `Weather.Cache` (ETS GenServer with 1-hour TTL), and `Dashboard` (Ecto queries for plant-now/recently-planted/upcoming). Weather tips are pure functions in `Weather.Tips`. The LiveView composes these on `mount/3` and degrades gracefully if weather is unavailable. A test stub module (`WeatherClientStub`) replaces the HTTP client in tests so no network calls are made.

**Tech Stack:** Phoenix LiveView, Elixir GenServer + ETS, Req 0.5 (HTTP client already in deps), OpenWeatherMap free-tier API, Tailwind CSS.

---

## File Map

### New files

| File | Responsibility |
|---|---|
| `lib/backyard_garden/weather/client.ex` | Two Req calls (current + forecast) → parsed map |
| `lib/backyard_garden/weather/cache.ex` | GenServer wrapping named ETS table; `get/1`, `put/2`, `clear/0` |
| `lib/backyard_garden/weather/tips.ex` | Pure functions: frost warning + temp/condition tips |
| `lib/backyard_garden/weather.ex` | Public facade: `get_weather/1` checks cache, calls client |
| `lib/backyard_garden/dashboard.ex` | `plant_now_seeds/1`, `recently_planted/1`, `upcoming_schedule/2` |
| `lib/backyard_garden_web/live/dashboard/index_live.ex` | LiveView mount + helper functions |
| `lib/backyard_garden_web/live/dashboard/index_live.html.heex` | Dashboard template |
| `test/support/weather_client_stub.ex` | Deterministic stub for `Weather.Client` behaviour in tests |
| `test/backyard_garden/weather/client_test.exs` | Client HTTP parsing via Req.Test stubs |
| `test/backyard_garden/weather/cache_test.exs` | Cache hit/miss/TTL |
| `test/backyard_garden/weather/tips_test.exs` | Tip generation logic |
| `test/backyard_garden/weather_test.exs` | Facade: cache-hit path + client-miss path |
| `test/backyard_garden/dashboard_test.exs` | plant_now, recently_planted, upcoming queries |
| `test/backyard_garden_web/live/dashboard/index_live_test.exs` | LiveView render + section content |

### Modified files

| File | Change |
|---|---|
| `lib/backyard_garden/application.ex` | Add `Weather.Cache` to supervision tree |
| `lib/backyard_garden_web/router.ex` | Replace `get "/", PageController, :home` with `live "/", Dashboard.IndexLive, :index` |
| `lib/backyard_garden_web/components/layouts.ex` | Add Dashboard nav link |
| `config/config.exs` | Add `:weather` and `:default_location` config keys |
| `config/test.exs` | Set `weather_client` stub + `default_location` for tests |

### Deleted files

| File | Reason |
|---|---|
| `lib/backyard_garden_web/controllers/page_controller.ex` | Replaced by Dashboard LiveView |
| `lib/backyard_garden_web/controllers/page_html.ex` | No longer needed |
| `lib/backyard_garden_web/controllers/page_html/home.html.heex` | Replaced by LiveView template |

---

## Task 1: Weather HTTP Client

**Files:**
- Create: `lib/backyard_garden/weather/client.ex`
- Create: `test/backyard_garden/weather/client_test.exs`
- Modify: `config/config.exs`
- Modify: `config/test.exs`

- [ ] **Step 1: Add weather config to `config/config.exs`**

Add before the `import_config` line at the bottom:

```elixir
config :backyard_garden, :weather,
  base_url: "https://api.openweathermap.org",
  api_key: System.get_env("OPENWEATHERMAP_API_KEY", "")

config :backyard_garden, :default_location, System.get_env("DEFAULT_LOCATION", "Victoria, BC")
```

- [ ] **Step 2: Add test weather config to `config/test.exs`**

Add to the end of the file:

```elixir
config :backyard_garden, :weather,
  base_url: "https://api.openweathermap.org",
  api_key: "test_key",
  req_options: [plug: {Req.Test, BackyardGarden.WeatherClientTest}]

config :backyard_garden, :default_location, "Victoria, BC"
```

- [ ] **Step 3: Write the failing client test**

Create `test/backyard_garden/weather/client_test.exs`:

```elixir
defmodule BackyardGarden.Weather.ClientTest do
  use ExUnit.Case, async: true

  alias BackyardGarden.Weather.Client

  # Helper that stubs both OWM endpoints for one test
  defp stub_success do
    Req.Test.stub(BackyardGarden.WeatherClientTest, fn conn ->
      case conn.request_path do
        "/data/2.5/weather" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "name" => "Victoria",
            "main" => %{"temp" => 12.5, "feels_like" => 10.0},
            "weather" => [%{"main" => "Clear", "description" => "clear sky", "icon" => "01d"}]
          }))

        "/data/2.5/forecast" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "list" => [
              %{
                "dt_txt" => "2026-04-04 12:00:00",
                "main" => %{"temp_min" => 6.0, "temp_max" => 14.0},
                "weather" => [%{"main" => "Clouds"}]
              },
              %{
                "dt_txt" => "2026-04-04 15:00:00",
                "main" => %{"temp_min" => 5.0, "temp_max" => 13.0},
                "weather" => [%{"main" => "Clouds"}]
              },
              %{
                "dt_txt" => "2026-04-05 12:00:00",
                "main" => %{"temp_min" => 3.0, "temp_max" => 10.0},
                "weather" => [%{"main" => "Rain"}]
              }
            ]
          }))
      end
    end)
  end

  test "fetch_weather returns parsed current conditions and forecast" do
    stub_success()

    assert {:ok, weather} = Client.fetch_weather("Victoria")

    assert weather.city == "Victoria"
    assert weather.temp == 12.5
    assert weather.feels_like == 10.0
    assert weather.condition == "Clear"
    assert weather.description == "clear sky"
    assert weather.icon == "01d"
    assert length(weather.forecast) == 2
  end

  test "forecast aggregates entries by date, taking the minimum temp_min per day" do
    stub_success()

    {:ok, weather} = Client.fetch_weather("Victoria")

    [day1, day2] = weather.forecast
    assert day1.min_temp == 5.0
    assert day1.condition == "Clouds"
    assert day2.min_temp == 3.0
    assert day2.condition == "Rain"
  end

  test "returns :city_not_found when OWM returns 404" do
    Req.Test.stub(BackyardGarden.WeatherClientTest, fn conn ->
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end)

    assert {:error, :city_not_found} = Client.fetch_weather("Nowhere")
  end

  test "returns :invalid_api_key when OWM returns 401" do
    Req.Test.stub(BackyardGarden.WeatherClientTest, fn conn ->
      Plug.Conn.send_resp(conn, 401, "Unauthorized")
    end)

    assert {:error, :invalid_api_key} = Client.fetch_weather("Victoria")
  end
end
```

- [ ] **Step 4: Run test to confirm failure**

```
mix test test/backyard_garden/weather/client_test.exs
```

Expected: compile error or `** (UndefinedFunctionError) BackyardGarden.Weather.Client is undefined`

- [ ] **Step 5: Create `lib/backyard_garden/weather/client.ex`**

```elixir
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
```

- [ ] **Step 6: Run tests — expect pass**

```
mix test test/backyard_garden/weather/client_test.exs
```

Expected: 4 tests, 0 failures

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/weather/client.ex \
        test/backyard_garden/weather/client_test.exs \
        config/config.exs config/test.exs
git commit -m "feat: add OpenWeatherMap HTTP client with Req.Test stubs"
```

---

## Task 2: ETS Weather Cache

**Files:**
- Create: `lib/backyard_garden/weather/cache.ex`
- Create: `test/backyard_garden/weather/cache_test.exs`
- Modify: `lib/backyard_garden/application.ex`

- [ ] **Step 1: Write the failing cache tests**

Create `test/backyard_garden/weather/cache_test.exs`:

```elixir
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
    :ets.insert(:weather_cache, {"Victoria", data, System.monotonic_time(:millisecond) - :timer.hours(2)})

    assert :miss = Cache.get("Victoria")
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```
mix test test/backyard_garden/weather/cache_test.exs
```

Expected: compile error — `BackyardGarden.Weather.Cache` undefined

- [ ] **Step 3: Create `lib/backyard_garden/weather/cache.ex`**

```elixir
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
```

- [ ] **Step 4: Add Cache to the supervision tree in `lib/backyard_garden/application.ex`**

Add `BackyardGarden.Weather.Cache` to the children list before `BackyardGardenWeb.Endpoint`:

```elixir
children = [
  BackyardGardenWeb.Telemetry,
  BackyardGarden.Repo,
  {DNSCluster, query: Application.get_env(:backyard_garden, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: BackyardGarden.PubSub},
  BackyardGarden.Weather.Cache,
  BackyardGardenWeb.Endpoint
]
```

- [ ] **Step 5: Run tests — expect pass**

```
mix test test/backyard_garden/weather/cache_test.exs
```

Expected: 4 tests, 0 failures

- [ ] **Step 6: Confirm server still starts**

```
mix compile --warnings-as-errors
```

Expected: compiles cleanly

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/weather/cache.ex \
        test/backyard_garden/weather/cache_test.exs \
        lib/backyard_garden/application.ex
git commit -m "feat: add ETS weather cache GenServer with 1-hour TTL"
```

---

## Task 3: Weather Facade, Tips, and Test Stub

**Files:**
- Create: `lib/backyard_garden/weather.ex`
- Create: `lib/backyard_garden/weather/tips.ex`
- Create: `test/support/weather_client_stub.ex`
- Create: `test/backyard_garden/weather_test.exs`
- Create: `test/backyard_garden/weather/tips_test.exs`
- Modify: `config/test.exs`

- [ ] **Step 1: Create the test stub module**

Create `test/support/weather_client_stub.ex`:

```elixir
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
```

- [ ] **Step 2: Add `weather_client` stub to `config/test.exs`**

Add to the end of `config/test.exs`:

```elixir
config :backyard_garden, :weather_client, BackyardGarden.WeatherClientStub
```

- [ ] **Step 3: Write failing weather facade tests**

Create `test/backyard_garden/weather_test.exs`:

```elixir
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
```

- [ ] **Step 4: Run to confirm failure**

```
mix test test/backyard_garden/weather_test.exs
```

Expected: compile error — `BackyardGarden.Weather` undefined

- [ ] **Step 5: Create `lib/backyard_garden/weather.ex`**

```elixir
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

  # Allows swapping in a stub via config :backyard_garden, :weather_client
  defp client do
    Application.get_env(:backyard_garden, :weather_client, BackyardGarden.Weather.Client)
  end
end
```

- [ ] **Step 6: Run weather tests — expect pass**

```
mix test test/backyard_garden/weather_test.exs
```

Expected: 4 tests, 0 failures

- [ ] **Step 7: Write failing tips tests**

Create `test/backyard_garden/weather/tips_test.exs`:

```elixir
defmodule BackyardGarden.Weather.TipsTest do
  use ExUnit.Case, async: true

  alias BackyardGarden.Weather.Tips

  defp weather(overrides \\ %{}) do
    Map.merge(
      %{
        temp: 12.5,
        condition: "Clear",
        forecast: [
          %{date: ~D[2026-04-04], min_temp: 6.0, condition: "Clouds"},
          %{date: ~D[2026-04-05], min_temp: 4.0, condition: "Clear"},
          %{date: ~D[2026-04-06], min_temp: 8.0, condition: "Rain"}
        ]
      },
      overrides
    )
  end

  test "returns a list of tip strings" do
    tips = Tips.generate(weather(), false)
    assert is_list(tips)
    assert length(tips) > 0
    assert Enum.all?(tips, &is_binary/1)
  end

  test "includes frost warning when forecast has temp below 2C and there are active plantings" do
    cold_forecast = [
      %{date: ~D[2026-04-04], min_temp: -1.0, condition: "Clear"},
      %{date: ~D[2026-04-05], min_temp: 0.5, condition: "Clear"},
      %{date: ~D[2026-04-06], min_temp: 3.0, condition: "Clouds"}
    ]

    tips = Tips.generate(weather(%{forecast: cold_forecast}), true)
    assert Enum.any?(tips, &String.contains?(&1, "Frost"))
  end

  test "omits frost warning when no plantings are active" do
    cold_forecast = [%{date: ~D[2026-04-04], min_temp: -1.0, condition: "Clear"}]

    tips = Tips.generate(weather(%{forecast: cold_forecast}), false)
    refute Enum.any?(tips, &String.contains?(&1, "Frost"))
  end

  test "omits frost warning when forecast stays above 2C" do
    warm_forecast = [%{date: ~D[2026-04-04], min_temp: 5.0, condition: "Clear"}]

    tips = Tips.generate(weather(%{forecast: warm_forecast}), true)
    refute Enum.any?(tips, &String.contains?(&1, "Frost"))
  end

  test "includes rain tip when condition contains Rain" do
    tips = Tips.generate(weather(%{condition: "Rain"}), false)
    assert Enum.any?(tips, &String.contains?(&1, "moisture"))
  end

  test "includes cool-season tip for temps between 5 and 15" do
    tips = Tips.generate(weather(%{temp: 10.0}), false)
    assert Enum.any?(tips, &String.contains?(&1, "cool"))
  end

  test "includes warm-season tip for temps between 15 and 25" do
    tips = Tips.generate(weather(%{temp: 20.0}), false)
    assert Enum.any?(tips, &String.contains?(&1, "warm-season"))
  end

  test "includes cold tip for temps below 5" do
    tips = Tips.generate(weather(%{temp: 3.0}), false)
    assert Enum.any?(tips, &String.contains?(&1, "cold-hardy"))
  end
end
```

- [ ] **Step 8: Run to confirm failure**

```
mix test test/backyard_garden/weather/tips_test.exs
```

Expected: compile error — `BackyardGarden.Weather.Tips` undefined

- [ ] **Step 9: Create `lib/backyard_garden/weather/tips.ex`**

```elixir
defmodule BackyardGarden.Weather.Tips do
  @moduledoc "Pure functions that derive planting tips from weather data."

  @doc """
  Returns a list of human-readable tip strings.

  `weather` is the map returned by `Weather.get_weather/1`.
  `has_planted` is `true` when there are plantings with status `"planted"`.
  """
  def generate(%{temp: temp, condition: condition, forecast: forecast}, has_planted) do
    []
    |> maybe_frost_warning(forecast, has_planted)
    |> add_temp_tip(temp)
    |> add_condition_tip(condition)
  end

  # --- private ---

  defp maybe_frost_warning(tips, forecast, true) do
    if Enum.any?(forecast, fn %{min_temp: t} -> t < 2.0 end) do
      ["Frost warning in the next 3 days — consider covering tender plants" | tips]
    else
      tips
    end
  end

  defp maybe_frost_warning(tips, _forecast, false), do: tips

  defp add_temp_tip(tips, temp) do
    tip =
      cond do
        temp < 5 ->
          "It's too cold for most seeds — stick to cold-hardy crops like spinach and kale"

        temp < 15 ->
          "Cool conditions are ideal for brassicas, greens, and root vegetables"

        temp < 25 ->
          "Great weather for warm-season crops like beans, zucchini, and tomatoes"

        true ->
          "Hot day — water new seedlings well and avoid planting in direct afternoon sun"
      end

    [tip | tips]
  end

  defp add_condition_tip(tips, condition) do
    if rainy?(condition) do
      ["Soil moisture is good today — ideal conditions for transplanting seedlings" | tips]
    else
      tips
    end
  end

  defp rainy?(condition) do
    String.contains?(String.downcase(condition || ""), ["rain", "drizzle", "shower"])
  end
end
```

- [ ] **Step 10: Run all weather tests — expect pass**

```
mix test test/backyard_garden/weather/
mix test test/backyard_garden/weather_test.exs
```

Expected: all pass

- [ ] **Step 11: Commit**

```bash
git add lib/backyard_garden/weather.ex \
        lib/backyard_garden/weather/tips.ex \
        test/support/weather_client_stub.ex \
        test/backyard_garden/weather_test.exs \
        test/backyard_garden/weather/tips_test.exs \
        config/test.exs
git commit -m "feat: add weather facade, tips module, and test stub"
```

---

## Task 4: Dashboard Context

**Files:**
- Create: `lib/backyard_garden/dashboard.ex`
- Create: `test/backyard_garden/dashboard_test.exs`

- [ ] **Step 1: Write the failing dashboard context tests**

Create `test/backyard_garden/dashboard_test.exs`:

```elixir
defmodule BackyardGarden.DashboardTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Dashboard
  alias BackyardGarden.{Seeds, Plantings}

  defp seed_fixture(attrs) do
    defaults = %{
      name: "Test Seed",
      type: "Vegetable",
      cycle: "Annual",
      ideal_planting_time: "spring",
      maturity_days: 50
    }

    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  describe "plant_now_seeds/1" do
    test "returns seeds whose window includes the given month" do
      seed = seed_fixture(%{name: "Spinach", ideal_planting_time: "spring"})

      # spring = {3, 5}, April is month 4
      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      assert "Spinach" in names
    end

    test "excludes seeds already planted" do
      seed = seed_fixture(%{name: "Planted Seed", ideal_planting_time: "spring"})
      planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Planted Seed" in names
    end

    test "excludes seeds already planned" do
      seed = seed_fixture(%{name: "Planned Seed", ideal_planting_time: "spring"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Planned Seed" in names
    end

    test "excludes seeds with no parseable planting time" do
      seed = seed_fixture(%{name: "Unknown", ideal_planting_time: nil})

      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Unknown" in names
    end

    test "excludes seeds out of their planting window" do
      seed = seed_fixture(%{name: "Summer Seed", ideal_planting_time: "summer"})

      # summer = {6, 8}, April is outside
      result = Dashboard.plant_now_seeds(~D[2026-04-03])
      names = Enum.map(result, & &1.name)

      refute "Summer Seed" in names
    end
  end

  describe "recently_planted/1" do
    test "returns planted plantings in descending planted_at order" do
      seed1 = seed_fixture(%{name: "Spinach"})
      seed2 = seed_fixture(%{name: "Chard"})
      planting_fixture(seed1, %{status: "planted", planted_at: ~D[2026-03-20]})
      planting_fixture(seed2, %{status: "planted", planted_at: ~D[2026-03-27]})

      [first | _] = Dashboard.recently_planted(5)
      assert first.seed.name == "Chard"
    end

    test "does not return planned or harvested plantings" do
      seed = seed_fixture(%{name: "Planned"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.recently_planted(5)
      names = Enum.map(result, & &1.seed.name)
      refute "Planned" in names
    end

    test "respects the limit" do
      seed = seed_fixture(%{name: "Repeated"})

      for i <- 1..10 do
        planting_fixture(seed, %{status: "planted", planted_at: Date.new!(2026, 3, i)})
      end

      assert length(Dashboard.recently_planted(3)) == 3
    end
  end

  describe "upcoming_schedule/2" do
    test "returns seeds with windows opening in the future within days_ahead" do
      # May = month 5; today is April 3, so May 1 is 28 days away
      seed = seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      assert "May Seed" in names
    end

    test "does not include seeds whose window opens today or in the past" do
      # April window opened April 1; today is April 3 — already in Plant Now
      seed = seed_fixture(%{name: "April Seed", ideal_planting_time: "april"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "April Seed" in names
    end

    test "does not include seeds beyond days_ahead" do
      # August = month 8; May 1 is only 28 days from April 3 so that's in range,
      # but August 1 is 120 days away — beyond 60
      seed = seed_fixture(%{name: "Far Future Seed", ideal_planting_time: "august"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "Far Future Seed" in names
    end

    test "excludes seeds already planted or planned" do
      seed = seed_fixture(%{name: "Already Planned May", ideal_planting_time: "may"})
      planting_fixture(seed, %{status: "planned"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      names = Enum.map(result, fn {s, _} -> s.name end)

      refute "Already Planned May" in names
    end

    test "returns results sorted by window open date" do
      seed_may = seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})
      seed_june = seed_fixture(%{name: "June Seed", ideal_planting_time: "june"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 90)
      names = Enum.map(result, fn {s, _} -> s.name end)

      may_idx = Enum.find_index(names, &(&1 == "May Seed"))
      june_idx = Enum.find_index(names, &(&1 == "June Seed"))

      assert may_idx < june_idx
    end

    test "includes the window open date in each result" do
      seed_fixture(%{name: "May Seed", ideal_planting_time: "may"})

      result = Dashboard.upcoming_schedule(~D[2026-04-03], 60)
      {_seed, open_date} = Enum.find(result, fn {s, _} -> s.name == "May Seed" end)

      assert open_date == ~D[2026-05-01]
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```
mix test test/backyard_garden/dashboard_test.exs
```

Expected: compile error — `BackyardGarden.Dashboard` undefined

- [ ] **Step 3: Create `lib/backyard_garden/dashboard.ex`**

```elixir
defmodule BackyardGarden.Dashboard do
  @moduledoc "Query functions for the Dashboard page."

  import Ecto.Query

  alias BackyardGarden.{Repo, Seeds, PlantingCalendar}
  alias BackyardGarden.Plantings.Planting

  @doc """
  Seeds whose ideal planting window includes the month of `date`,
  excluding seeds that already have a "planted" or "planned" planting.
  """
  def plant_now_seeds(date \\ Date.utc_today()) do
    active_ids = active_seed_ids()

    Seeds.list_seeds()
    |> Enum.reject(&(&1.id in active_ids))
    |> Enum.filter(&in_planting_window?(&1, date))
  end

  @doc "Returns the `limit` most recently planted plantings with seed preloaded."
  def recently_planted(limit \\ 5) do
    Planting
    |> where([p], p.status == "planted" and not is_nil(p.planted_at))
    |> order_by([p], desc: p.planted_at)
    |> limit(^limit)
    |> preload(:seed)
    |> Repo.all()
  end

  @doc """
  Seeds whose ideal planting window opens between 1 and `days_ahead` days after `date`,
  excluding seeds that already have a "planted" or "planned" planting.
  Returns `[{seed, window_open_date}]` sorted by `window_open_date`.
  """
  def upcoming_schedule(date \\ Date.utc_today(), days_ahead \\ 60) do
    active_ids = active_seed_ids()

    Seeds.list_seeds()
    |> Enum.reject(&(&1.id in active_ids))
    |> Enum.flat_map(fn seed ->
      case upcoming_open_date(seed, date, days_ahead) do
        nil -> []
        open_date -> [{seed, open_date}]
      end
    end)
    |> Enum.sort_by(&elem(&1, 1), Date)
  end

  # --- private ---

  defp active_seed_ids do
    Planting
    |> where([p], p.status in ["planted", "planned"])
    |> select([p], p.seed_id)
    |> Repo.all()
  end

  defp in_planting_window?(seed, %Date{month: month}) do
    case PlantingCalendar.parse_ideal_months(seed.ideal_planting_time) do
      nil -> false
      {start_m, end_m} -> month_in_range?(month, start_m, end_m)
    end
  end

  # Normal range: start_m <= end_m (e.g., March–May)
  defp month_in_range?(month, start_m, end_m) when start_m <= end_m do
    month >= start_m and month <= end_m
  end

  # Wrap-around range: start_m > end_m (e.g., Nov–Feb for winter)
  defp month_in_range?(month, start_m, end_m) do
    month >= start_m or month <= end_m
  end

  # Returns the first day of the next occurrence of `start_m` that is strictly
  # after `from` and within `days_ahead`. Returns nil otherwise.
  defp upcoming_open_date(seed, from, days_ahead) do
    case PlantingCalendar.parse_ideal_months(seed.ideal_planting_time) do
      nil ->
        nil

      {start_m, _end_m} ->
        open_date = next_month_first(from, start_m)
        days_until = Date.diff(open_date, from)

        if days_until >= 1 and days_until <= days_ahead, do: open_date, else: nil
    end
  end

  # Returns the 1st of `month` in the current year if that date is after `from`,
  # otherwise the 1st of `month` in the following year.
  defp next_month_first(%Date{year: year} = from, month) do
    candidate = Date.new!(year, month, 1)

    if Date.compare(candidate, from) == :gt do
      candidate
    else
      Date.new!(year + 1, month, 1)
    end
  end
end
```

- [ ] **Step 4: Run tests — expect pass**

```
mix test test/backyard_garden/dashboard_test.exs
```

Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/backyard_garden/dashboard.ex \
        test/backyard_garden/dashboard_test.exs
git commit -m "feat: add Dashboard context with plant-now, recently-planted, and upcoming queries"
```

---

## Task 5: Dashboard LiveView Scaffold — Route, Nav, Basic Render

**Files:**
- Create: `lib/backyard_garden_web/live/dashboard/index_live.ex`
- Create: `lib/backyard_garden_web/live/dashboard/index_live.html.heex`
- Create: `test/backyard_garden_web/live/dashboard/index_live_test.exs`
- Modify: `lib/backyard_garden_web/router.ex`
- Modify: `lib/backyard_garden_web/components/layouts.ex`
- Delete: `lib/backyard_garden_web/controllers/page_controller.ex`
- Delete: `lib/backyard_garden_web/controllers/page_html.ex`
- Delete: `lib/backyard_garden_web/controllers/page_html/home.html.heex`

- [ ] **Step 1: Write the failing LiveView render test**

Create `test/backyard_garden_web/live/dashboard/index_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Dashboard.IndexLiveTest do
  use BackyardGardenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BackyardGarden.{Seeds, Plantings}

  defp seed_fixture(attrs) do
    defaults = %{name: "Test Seed", type: "Vegetable", cycle: "Annual", maturity_days: 50}
    {:ok, seed} = Seeds.create_seed(Map.merge(defaults, attrs))
    seed
  end

  defp planting_fixture(seed, attrs) do
    defaults = %{seed_id: seed.id, status: "planned"}
    {:ok, planting} = Plantings.create_planting(Map.merge(defaults, attrs))
    planting
  end

  test "renders the dashboard page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Plant Now"
    assert html =~ "Recently Planted"
    assert html =~ "Coming Up"
  end

  test "renders weather widget when weather is available", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    # WeatherClientStub returns temp 12.5 for "Victoria, BC"
    assert html =~ "12.5"
    assert html =~ "Victoria"
  end

  test "shows a seed in Plant Now when its window is open and it is not planted", %{conn: conn} do
    seed_fixture(%{name: "April Spinach", ideal_planting_time: "spring"})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "April Spinach"
  end

  test "does not show a planted seed in Plant Now", %{conn: conn} do
    seed = seed_fixture(%{name: "Already Planted", ideal_planting_time: "spring"})
    planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/")

    # "Already Planted" should not appear in Plant Now (it will appear in Recently Planted)
    # Count occurrences — it should appear at most once (in recently planted), not twice
    count = html |> String.split("Already Planted") |> length() |> Kernel.-(1)
    assert count <= 1
  end

  test "shows a recently planted item in Recently Planted", %{conn: conn} do
    seed = seed_fixture(%{name: "Recent Basil"})
    planting_fixture(seed, %{status: "planted", planted_at: ~D[2026-03-27]})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Recent Basil"
  end

  test "shows upcoming seeds in Coming Up", %{conn: conn} do
    # May window will show as upcoming in April
    seed_fixture(%{name: "May Beans", ideal_planting_time: "may"})

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "May Beans"
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: failure — `BackyardGardenWeb.Dashboard.IndexLive` undefined or route not found

- [ ] **Step 3: Update the router**

In `lib/backyard_garden_web/router.ex`, replace:

```elixir
get "/", PageController, :home
```

with:

```elixir
live "/", Dashboard.IndexLive, :index
```

- [ ] **Step 4: Add Dashboard link to nav in `lib/backyard_garden_web/components/layouts.ex`**

In the `app/1` function, add a Dashboard link as the first nav item inside the `<div class="flex items-center gap-6 ...">` block:

```elixir
<div class="flex items-center gap-6 text-sm font-medium">
  <.nav_link href={~p"/"} current_scope={@current_scope}>Dashboard</.nav_link>
  <.nav_link href={~p"/seeds"} current_scope={@current_scope}>Seeds</.nav_link>
  <.nav_link href={~p"/garden"} current_scope={@current_scope}>My Garden</.nav_link>
  <.nav_link href={~p"/calendar"} current_scope={@current_scope}>Calendar</.nav_link>
  <.nav_link href={~p"/settings/zones"} current_scope={@current_scope}>Zones</.nav_link>
</div>
```

- [ ] **Step 5: Delete old controller and templates**

```bash
rm lib/backyard_garden_web/controllers/page_controller.ex
rm lib/backyard_garden_web/controllers/page_html.ex
rm lib/backyard_garden_web/controllers/page_html/home.html.heex
```

- [ ] **Step 6: Create the LiveView module**

Create `lib/backyard_garden_web/live/dashboard/index_live.ex`:

```elixir
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
```

- [ ] **Step 7: Create a minimal template to unblock tests**

Create `lib/backyard_garden_web/live/dashboard/index_live.html.heex`:

```heex
<div class="space-y-6">
  <h1 class="text-2xl font-bold text-[#14532d]">Dashboard</h1>

  <p>Plant Now</p>
  <p>Recently Planted</p>
  <p>Coming Up</p>

  <%= if @weather do %>
    <p>{@weather.city} {@weather.temp}</p>
  <% end %>

  <ul>
    <%= for seed <- @plant_now do %>
      <li>{seed.name}</li>
    <% end %>
  </ul>

  <ul>
    <%= for planting <- @recently_planted do %>
      <li>{planting.seed.name}</li>
    <% end %>
  </ul>

  <ul>
    <%= for {seed, _date} <- @upcoming do %>
      <li>{seed.name}</li>
    <% end %>
  </ul>
</div>
```

- [ ] **Step 8: Run LiveView tests — expect pass**

```
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: all tests pass

- [ ] **Step 9: Compile cleanly**

```
mix compile --warnings-as-errors
```

Expected: no warnings

- [ ] **Step 10: Commit**

```bash
git add lib/backyard_garden_web/live/dashboard/ \
        lib/backyard_garden_web/router.ex \
        lib/backyard_garden_web/components/layouts.ex \
        test/backyard_garden_web/live/dashboard/
git commit -m "feat: add Dashboard LiveView at /, remove PageController home page"
```

---

## Task 6: Dashboard Template — Botanical Design

**Files:**
- Modify: `lib/backyard_garden_web/live/dashboard/index_live.html.heex`

The tests from Task 5 already cover content. This task replaces the placeholder template with the full botanical-style design. No new tests are needed — run the existing suite to confirm nothing breaks.

- [ ] **Step 1: Replace the placeholder template with the full design**

Overwrite `lib/backyard_garden_web/live/dashboard/index_live.html.heex`:

```heex
<div class="space-y-6">
  <%!-- Weather banner (hidden when weather unavailable) --%>
  <%= if @weather do %>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
      <div class="flex items-start justify-between gap-4">
        <div>
          <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold">
            {@weather.city}
          </span>
          <div class="flex items-baseline gap-3 mt-1">
            <span class="text-4xl font-bold text-[#14532d]">
              {Float.round(@weather.temp, 1)}°C
            </span>
            <span class="text-[#374151] text-lg">{@weather.condition}</span>
          </div>
        </div>
        <%= if length(@weather_tips) > 0 do %>
          <div class="max-w-xs">
            <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold">
              Today's Tip
            </span>
            <p class="mt-1 text-sm text-[#374151] italic">
              {List.first(@weather_tips)}
            </p>
          </div>
        <% end %>
      </div>
      <%!-- Frost warning shown prominently if present --%>
      <%= if Enum.any?(@weather_tips, &String.contains?(&1, "Frost")) do %>
        <div class="mt-4 flex items-center gap-2 rounded-lg bg-[#fef3c7] border border-[#fcd34d] px-4 py-2">
          <span class="text-[#92400e] text-sm font-medium">
            {Enum.find(@weather_tips, &String.contains?(&1, "Frost"))}
          </span>
        </div>
      <% end %>
    </div>
  <% end %>

  <%!-- Two-column: Plant Now + Recently Planted --%>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <%!-- Plant Now --%>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
      <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold">
        Plant Now
      </span>
      <%= if @plant_now == [] do %>
        <p class="mt-3 text-sm text-[#6b7280]">
          No seeds are in their ideal window right now.
        </p>
      <% else %>
        <ul class="mt-3 space-y-2">
          <%= for seed <- @plant_now do %>
            <li class="flex items-center justify-between gap-2">
              <div class="flex items-center gap-2">
                <span class="w-2 h-2 rounded-full bg-[#2d6a4f] shrink-0"></span>
                <a
                  href={~p"/seeds/#{seed.id}"}
                  class="text-[#14532d] font-medium hover:underline"
                >
                  {seed.name}
                </a>
              </div>
              <BackyardGardenWeb.Layouts.type_badge type={seed.type} />
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>

    <%!-- Recently Planted --%>
    <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
      <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold">
        Recently Planted
      </span>
      <%= if @recently_planted == [] do %>
        <p class="mt-3 text-sm text-[#6b7280]">Nothing planted yet.</p>
      <% else %>
        <ul class="mt-3 space-y-2">
          <%= for planting <- @recently_planted do %>
            <li class="flex items-center justify-between">
              <a
                href={~p"/seeds/#{planting.seed.id}"}
                class="text-[#374151] hover:text-[#14532d] hover:underline"
              >
                {planting.seed.name}
              </a>
              <span class="text-[#6b7280] text-sm">
                {Calendar.strftime(planting.planted_at, "%b %d")}
              </span>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
  </div>

  <%!-- Upcoming Schedule (full width) --%>
  <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
    <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold">
      Coming Up
    </span>
    <%= if @upcoming == [] do %>
      <p class="mt-3 text-sm text-[#6b7280]">
        No upcoming planting windows in the next 60 days.
      </p>
    <% else %>
      <div class="mt-3 divide-y divide-[#f0fdf4]">
        <%= for {seed, open_date} <- @upcoming do %>
          <div class="flex items-center gap-4 py-2">
            <span class="text-[#6b7280] text-sm w-14 shrink-0">
              {Calendar.strftime(open_date, "%b %d")}
            </span>
            <a
              href={~p"/seeds/#{seed.id}"}
              class="text-[#374151] font-medium hover:text-[#14532d] hover:underline flex-1"
            >
              {seed.name}
            </a>
            <BackyardGardenWeb.Layouts.type_badge type={seed.type} />
            <span class="text-[#6b7280] text-xs hidden sm:block">ideal window opens</span>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Run full test suite — expect pass**

```
mix test
```

Expected: all tests pass, no failures

- [ ] **Step 3: Check the page renders in browser**

```
mix phx.server
```

Open `http://localhost:4000` and confirm:
- Weather widget shows (requires `OPENWEATHERMAP_API_KEY` env var — blank key will result in no weather widget showing, which is expected)
- Three sections visible: Plant Now, Recently Planted, Coming Up
- Nav shows Dashboard link
- All links to seed detail pages work

- [ ] **Step 4: Run pre-commit checks**

```
mix precommit
```

Expected: compiles, formats, tests all pass

- [ ] **Step 5: Commit**

```bash
git add lib/backyard_garden_web/live/dashboard/index_live.html.heex
git commit -m "feat: botanical dashboard template with weather widget and three data sections"
```

---

## Task 7: Mark Phase 3 Complete and Final Checks

- [ ] **Step 1: Run linting**

```
mix credo
mix sobelow
```

Expected: no issues (Sobelow may flag the `get_env` API key approach — this is acceptable for Phase 3; the key is never logged or rendered)

- [ ] **Step 2: Update Plan.md — mark Phase 3 tasks complete**

In `Plan.md`, change the Phase 3 section from:

```markdown
### Phase 3 — Dashboard & Weather

- [ ] 3.1 Dashboard page — plant-now list, recently planted, upcoming schedule
- [ ] 3.2 OpenWeatherMap integration — current conditions widget
- [ ] 3.3 Weather caching (ETS, 1-hour TTL)
- [ ] 3.4 Weather-aware planting tips (frost warning, soil temp guidance)
```

to:

```markdown
### Phase 3 — Dashboard & Weather ✅ Complete

- [x] 3.1 Dashboard page — plant-now list, recently planted, upcoming schedule
- [x] 3.2 OpenWeatherMap integration — current conditions widget
- [x] 3.3 Weather caching (ETS, 1-hour TTL)
- [x] 3.4 Weather-aware planting tips (frost warning, soil temp guidance)
```

- [ ] **Step 3: Run full test suite one final time**

```
mix test
```

Expected: all tests pass

- [ ] **Step 4: Final commit**

```bash
git add Plan.md
git commit -m "docs: mark Phase 3 complete in Plan.md"
```

---

## Key Implementation Notes

### Weather API Key
Set `OPENWEATHERMAP_API_KEY` in the environment before running the dev server. Sign up at openweathermap.org for a free key (1,000 calls/day). With no key set, `Weather.Client` returns `{:error, :invalid_api_key}` and the dashboard renders without the weather widget.

### Test Stub vs Real Client
- `BackyardGarden.WeatherClientStub` (in `test/support/`) is used for all non-Client tests via `config :backyard_garden, :weather_client` in `config/test.exs`.
- `BackyardGarden.Weather.Client` tests use `Req.Test.stub/2` directly with the `BackyardGarden.WeatherClientTest` plug name configured in `config/test.exs`.

### Dashboard date dependency
`Dashboard.plant_now_seeds/1` and `Dashboard.upcoming_schedule/2` accept a `date` parameter defaulting to `Date.utc_today()`. The LiveView calls them with no arguments. Tests pass explicit dates so they are not sensitive to when the test suite runs.

### Weather cache in tests
`Cache.clear/0` is called in each weather cache test's `setup` block. The Dashboard LiveView tests bypass the real cache because `config :backyard_garden, :weather_client` points to the stub — the stub never calls `Cache.put/2`, so the cache is irrelevant in those tests.
