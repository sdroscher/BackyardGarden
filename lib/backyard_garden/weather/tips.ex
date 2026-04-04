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
          "Great cool-weather conditions — ideal for brassicas, greens, and root vegetables"

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
