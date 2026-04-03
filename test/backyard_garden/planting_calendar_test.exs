defmodule BackyardGarden.PlantingCalendarTest do
  use ExUnit.Case, async: true

  alias BackyardGarden.PlantingCalendar

  describe "parse_ideal_months/1" do
    test "returns nil for nil input" do
      assert PlantingCalendar.parse_ideal_months(nil) == nil
    end

    test "returns nil for empty string" do
      assert PlantingCalendar.parse_ideal_months("") == nil
    end

    test "parses 'Early Spring' to March-April" do
      assert PlantingCalendar.parse_ideal_months("Early Spring") == {3, 4}
    end

    test "parses 'Late Spring' to April-May" do
      assert PlantingCalendar.parse_ideal_months("Late Spring") == {4, 5}
    end

    test "parses 'Spring' to March-May" do
      assert PlantingCalendar.parse_ideal_months("Spring") == {3, 5}
    end

    test "parses 'Early/Late Spring' to March-May" do
      assert PlantingCalendar.parse_ideal_months("Early/Late Spring") == {3, 5}
    end

    test "parses month range 'April-July'" do
      assert PlantingCalendar.parse_ideal_months("April-July") == {4, 7}
    end

    test "parses 'Late April' to April-April" do
      assert PlantingCalendar.parse_ideal_months("Late April") == {4, 4}
    end

    test "parses 'Early April' to April-April" do
      assert PlantingCalendar.parse_ideal_months("Early April") == {4, 4}
    end

    test "parses 'Summer' to June-August" do
      assert PlantingCalendar.parse_ideal_months("Summer") == {6, 8}
    end

    test "parses 'Fall' to September-October" do
      assert PlantingCalendar.parse_ideal_months("Fall") == {9, 10}
    end

    test "returns nil for unrecognised string" do
      assert PlantingCalendar.parse_ideal_months("whenever") == nil
    end
  end

  describe "weeks_for_month/1" do
    test "returns list of week lists for April 2026" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      # April 2026 starts on Wednesday (day 3)
      assert length(weeks) == 5
      # First week: Monday=nil, Tuesday=nil, Wednesday=Apr 1 …
      [first_week | _] = weeks
      assert Enum.at(first_week, 0) == nil
      assert Enum.at(first_week, 1) == nil
      assert Enum.at(first_week, 2) == ~D[2026-04-01]
    end

    test "each week has exactly 7 entries" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      assert Enum.all?(weeks, fn week -> length(week) == 7 end)
    end

    test "all actual dates are in the given month" do
      weeks = PlantingCalendar.weeks_for_month(~D[2026-04-01])
      dates = weeks |> List.flatten() |> Enum.reject(&is_nil/1)
      assert Enum.all?(dates, fn d -> d.month == 4 and d.year == 2026 end)
    end
  end

  describe "month_range/1" do
    test "returns first and last day for April 2026" do
      {first, last} = PlantingCalendar.month_range(~D[2026-04-01])
      assert first == ~D[2026-04-01]
      assert last == ~D[2026-04-30]
    end
  end
end
