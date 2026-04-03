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
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "name" => "Victoria",
              "main" => %{"temp" => 12.5, "feels_like" => 10.0},
              "weather" => [%{"main" => "Clear", "description" => "clear sky", "icon" => "01d"}]
            })
          )

        "/data/2.5/forecast" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
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
            })
          )
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
