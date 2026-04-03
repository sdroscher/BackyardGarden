defmodule BackyardGarden.PlantingCalendar do
  @moduledoc """
  Helpers for the planting calendar: ideal planting time parser and month grid builder.
  """

  @month_names %{
    "january" => 1,
    "february" => 2,
    "march" => 3,
    "april" => 4,
    "may" => 5,
    "june" => 6,
    "july" => 7,
    "august" => 8,
    "september" => 9,
    "october" => 10,
    "november" => 11,
    "december" => 12
  }

  @doc """
  Parses an `ideal_planting_time` string into a `{start_month, end_month}` tuple (1-12).
  Returns nil for unrecognised or empty input.
  """
  def parse_ideal_months(nil), do: nil
  def parse_ideal_months(""), do: nil

  def parse_ideal_months(text) do
    text |> String.trim() |> String.downcase() |> do_parse()
  end

  @doc """
  Returns a list of week lists (each week is 7 entries of `Date.t() | nil`)
  for the month containing `first_day`. Weeks start on Monday.
  nil entries pad the first and last weeks.
  """
  def weeks_for_month(%Date{} = first_day) do
    first = %{first_day | day: 1}
    last = Date.end_of_month(first)

    all_dates = Date.range(first, last) |> Enum.to_list()

    leading_nils = List.duplicate(nil, Date.day_of_week(first) - 1)
    trailing_nils = List.duplicate(nil, 7 - Date.day_of_week(last))

    (leading_nils ++ all_dates ++ trailing_nils)
    |> Enum.chunk_every(7)
  end

  @doc "Returns {first_day, last_day} for the month containing the given date."
  def month_range(%Date{} = date) do
    first = %{date | day: 1}
    {first, Date.end_of_month(first)}
  end

  # Private parsers — ordered most-specific to least-specific

  defp do_parse("early spring"), do: {3, 4}
  defp do_parse("early/late spring"), do: {3, 5}
  defp do_parse("late spring"), do: {4, 5}
  defp do_parse("spring"), do: {3, 5}
  defp do_parse("early summer"), do: {6, 7}
  defp do_parse("summer"), do: {6, 8}
  defp do_parse("early fall"), do: {9, 9}
  defp do_parse("fall"), do: {9, 10}
  defp do_parse("autumn"), do: {9, 10}
  defp do_parse("early winter"), do: {11, 12}
  defp do_parse("winter"), do: {11, 2}

  # "April-July" → {4, 7}
  defp do_parse(text) do
    with [start_name, end_name] <- String.split(text, "-", parts: 2),
         start_m when not is_nil(start_m) <- Map.get(@month_names, String.trim(start_name)),
         end_m when not is_nil(end_m) <- Map.get(@month_names, String.trim(end_name)) do
      {start_m, end_m}
    else
      _ -> parse_qualified_month(text)
    end
  end

  # "late april" → {4, 4}, "early april" → {4, 4}, "april" → {4, 4}
  defp parse_qualified_month(text) do
    cond do
      String.starts_with?(text, "early ") ->
        month_from_suffix(text, "early ")

      String.starts_with?(text, "late ") ->
        month_from_suffix(text, "late ")

      true ->
        case Map.get(@month_names, text) do
          nil -> nil
          m -> {m, m}
        end
    end
  end

  defp month_from_suffix(text, prefix) do
    suffix = String.replace_prefix(text, prefix, "")

    case Map.get(@month_names, suffix) do
      nil -> nil
      m -> {m, m}
    end
  end
end
