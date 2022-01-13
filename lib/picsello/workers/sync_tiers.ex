defmodule Picsello.Workers.SyncTiers do
  @moduledoc "fetches pricing calculator data from google sheet"
  use Oban.Worker, queue: :default

  alias GoogleApi.Sheets.V4, as: Sheets

  alias Picsello.{
    Repo,
    Packages.BasePrice,
    Packages.Tier,
    Packages.CostOfLivingAdjustment
  }

  @job_type_map %{
    "Maternity & Newborn" => "newborn",
    "Mini Session" => "mini"
  }

  def perform(_) do
    {:ok, %{token: token}} =
      Goth.Token.for_scope("https://www.googleapis.com/auth/spreadsheets.readonly")

    connection = Sheets.Connection.new(token)
    {_number, _values} = sync_base_prices(connection)
    {_number, _values} = sync_cost_of_living(connection)

    :ok
  end

  defp get_sheet_values(connection, range) do
    {:ok, %{values: rows}} =
      Sheets.Api.Spreadsheets.sheets_spreadsheets_values_get(
        connection,
        Keyword.get(config(), :sheet_id),
        Keyword.get(config(), range)
      )

    rows
  end

  defp sync_base_prices(connection) do
    rows = get_sheet_values(connection, :prices)

    rows =
      for([time, experience_range, type, tier, base_price, shoots, downloads] <- tl(rows)) do
        [min_years_experience] = Regex.run(~r/^\d+/, experience_range)
        job_type = Map.get(@job_type_map, type, String.downcase(type))

        base_price_dollars =
          Regex.scan(~r/\d+/, base_price) |> List.flatten() |> Enum.join() |> String.to_integer()

        %{
          full_time: time != "Part-Time",
          min_years_experience: String.to_integer(min_years_experience),
          job_type: job_type,
          base_price: base_price_dollars * 100,
          tier: String.downcase(tier),
          shoot_count: String.to_integer(shoots),
          download_count: String.to_integer(downloads)
        }
      end

    Repo.insert_all(
      Tier,
      [
        %{name: "bronze", position: 0},
        %{name: "silver", position: 1},
        %{name: "gold", position: 2}
      ],
      on_conflict: :nothing
    )

    Repo.insert_all(BasePrice, rows,
      on_conflict: {:replace, ~w[base_price shoot_count download_count]a},
      conflict_target: ~w[tier job_type full_time min_years_experience]a
    )
  end

  defp sync_cost_of_living(connection) do
    rows = get_sheet_values(connection, :cost_of_living)

    rows =
      for([state, percent] <- tl(rows)) do
        multiplier =
          Decimal.new(1)
          |> Decimal.add(
            Regex.run(~r/-?\d+/, percent)
            |> hd
            |> Decimal.new()
            |> Decimal.div(Decimal.new(100))
          )

        %{state: state, multiplier: multiplier}
      end

    Repo.insert_all(CostOfLivingAdjustment, rows,
      on_conflict: {:replace, [:multiplier]},
      conflict_target: [:state]
    )
  end

  defp config(), do: :picsello |> Application.get_env(:packages) |> Keyword.get(:calculator)
end
