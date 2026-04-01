# priv/repo/seeds.exs
# Run with: mix run priv/repo/seeds.exs
#
# Idempotent: skips seeds that already exist (matched by name + brand).

alias BackyardGarden.Repo
alias BackyardGarden.Seeds.Seed

NimbleCSV.define(SeedCSVParser, separator: ",", escape: "\"")

csv_path = Path.join(File.cwd!(), "Seed Planting 2026.csv")

unless File.exists?(csv_path) do
  IO.puts("ERROR: #{csv_path} not found. Run from project root.")
  System.halt(1)
end

csv_path
|> File.stream!()
|> SeedCSVParser.parse_stream(skip_headers: true)
|> Enum.each(fn row ->
  # Pad to 11 columns in case trailing empty fields were stripped
  padded = row ++ List.duplicate("", 11)

  [name, brand, type, cycle, _when_bought, planting_method, ideal_planting_time,
   _actually_planted, maturity | _rest] = padded

  maturity_days =
    case Regex.run(~r/(\d+)/, maturity) do
      [_, n] -> String.to_integer(n)
      nil -> nil
    end

  attrs = %{
    name: String.trim(name),
    brand: String.trim(brand),
    type: String.trim(type),
    cycle: String.trim(cycle),
    planting_method: String.trim(planting_method),
    ideal_planting_time: String.trim(ideal_planting_time),
    maturity_days: maturity_days
  }

  case Repo.get_by(Seed, name: attrs.name, brand: attrs.brand) do
    nil ->
      case Seed.changeset(%Seed{}, attrs) |> Repo.insert() do
        {:ok, seed} -> IO.puts("  + Inserted: #{seed.name}")
        {:error, cs} -> IO.puts("  ! Failed:   #{attrs.name} — #{inspect(cs.errors)}")
      end

    _existing ->
      IO.puts("  ~ Skipped:  #{attrs.name}")
  end
end)

total = Repo.aggregate(Seed, :count, :id)
IO.puts("\nDone. Total seeds in database: #{total}")
