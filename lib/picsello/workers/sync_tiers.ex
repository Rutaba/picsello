defmodule Picsello.Workers.SyncTiers do
  @moduledoc "fetches smart profit calculator data from google sheet"
  use Oban.Worker, queue: :default

  alias GoogleApi.Sheets.V4, as: Sheets

  alias Picsello.{
    Repo,
    Packages.BasePrice,
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
    [_header | rows] = get_sheet_values(connection, :prices)

    rows =
      for(row <- rows) do
        [
          time,
          experience_range,
          type,
          tier,
          base_price,
          shoots,
          downloads,
          turnaround,
          max_session_per_year,
          description
        ] = cells_by_column(row, [?A, ?B, ?C, ?D, ?E, ?F, ?G, ?H, ?I, ?T])

        [min_years_experience] = Regex.run(~r/^\d+/, experience_range)
        job_type = Map.get(@job_type_map, type, String.downcase(type))

        %{
          full_time: time != "Part-Time",
          min_years_experience: String.to_integer(min_years_experience),
          job_type: job_type,
          base_price: price_to_cents(base_price),
          tier: tier |> String.downcase() |> String.trim(),
          shoot_count: String.to_integer(shoots),
          download_count: String.to_integer(downloads),
          turnaround_weeks: String.to_integer(turnaround),
          max_session_per_year: String.to_integer(max_session_per_year),
          description: description
        }
      end

    Repo.insert_all(BasePrice, rows,
      on_conflict:
        {:replace,
         ~w[base_price shoot_count download_count turnaround_weeks max_session_per_year description]a},
      conflict_target: ~w[tier job_type full_time min_years_experience]a
    )
  end

  defp cells_by_column(row, columns) do
    columns
    |> Enum.map(fn column ->
      row |> Enum.at(column - ?A)
    end)
  end

  defp price_to_cents(price) do
    Regex.scan(~r/\d+/, price) |> List.flatten() |> Enum.join() |> String.to_integer()
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
