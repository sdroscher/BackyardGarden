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
    refute Enum.empty?(tips)
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

  describe "contextual_message/2" do
    test "warm + dry + seeds ready" do
      msg = Tips.contextual_message(%{temp: 18.0, condition: "Clear"}, 5)
      assert msg =~ "5 seeds"
      assert msg =~ ~r/planting|ground/i
    end

    test "warm + dry + no seeds ready" do
      msg = Tips.contextual_message(%{temp: 18.0, condition: "Clear"}, 0)
      assert msg =~ ~r/outside|garden/i
      refute msg =~ "seeds ready"
    end

    test "rainy day" do
      msg = Tips.contextual_message(%{temp: 16.0, condition: "Rain"}, 3)
      assert msg =~ ~r/transplant|rain|moisture/i
    end

    test "cold day" do
      msg = Tips.contextual_message(%{temp: 3.0, condition: "Clear"}, 0)
      assert msg =~ ~r/cold|hardy/i
    end

    test "hot day" do
      msg = Tips.contextual_message(%{temp: 30.0, condition: "Clear"}, 2)
      assert msg =~ ~r/water|heat|hot/i
    end
  end
end
