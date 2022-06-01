defmodule Picsello.Workers.SyncEmailPresets do
  @moduledoc "fetches email preset content from google sheet"
  require Logger

  use Oban.Worker, queue: :default

  alias GoogleApi.Sheets.V4, as: Sheets
  alias Picsello.{Repo, EmailPreset}
  import Ecto.Query, only: [from: 2]

  def perform(), do: perform(%{args: config()})

  def perform(%{args: %{type_ranges: %{}} = config}) do
    {:ok, %{token: token}} =
      Goth.Token.for_scope("https://www.googleapis.com/auth/spreadsheets.readonly")

    connection = Sheets.Connection.new(token)

    now = DateTime.truncate(DateTime.utc_now(), :second)

    {type_ranges, config} = Map.pop(config, :type_ranges, [])

    rows =
      type_ranges
      |> Enum.map(&fetch_sheet(&1, connection, config))
      |> Enum.concat()
      |> Enum.map(&Map.merge(&1, %{updated_at: now, inserted_at: now, type: :job}))

    Repo.transaction(fn ->
      job_types = Picsello.JobType.all()

      rows = Enum.filter(rows, &Enum.member?(job_types, Map.get(&1, :job_type)))

      {_count, presets} =
        Repo.insert_all(EmailPreset, rows,
          on_conflict: {:replace, ~w[subject_template body_template]a},
          conflict_target: ~w[state job_type name]a,
          returning: [:id]
        )

      ids = Enum.map(presets, &Map.get(&1, :id))

      from(preset in EmailPreset, where: preset.id not in ^ids)
      |> Repo.delete_all()
    end)
  end

  def perform(_), do: perform()

  defp fetch_sheet({type, range}, connection, %{sheet_id: sheet_id, column_map: column_map}) do
    {:ok, %{values: [keys | rows]}} =
      Sheets.Api.Spreadsheets.sheets_spreadsheets_values_get(connection, sheet_id, range)

    keys =
      for(
        key <- trim_all(keys),
        do: Map.get(column_map, String.downcase(key), key)
      )

    rows
    |> Enum.with_index()
    |> Enum.reduce(
      [],
      fn {row, index}, acc ->
        try do
          [
            keys
            |> Enum.zip(trim_all(row))
            |> Enum.into(%{job_type: type})
            |> Map.take([:job_type | Map.values(column_map)])
            |> Map.put(:position, index)
            |> Map.update!(:name, &Regex.replace(~r/^DEFAULT\s*-\s*/, &1, ""))
            |> Map.update!(
              :state,
              &(&1
                |> String.downcase()
                |> String.replace(~r/\s+/, "_")
                |> String.to_existing_atom())
            )
            | acc
          ]
        rescue
          e ->
            Logger.warn("skipping row #{inspect(row)} because #{inspect(e)}")
            acc
        end
      end
    )
  end

  defp trim_all(list), do: Enum.map(list, &String.trim/1)

  defp config do
    Application.get_env(:picsello, :email_presets)
    |> Keyword.update(:type_ranges, "", &URI.decode_query/1)
    |> Keyword.update(
      :column_map,
      "",
      &(&1
        |> URI.decode_query()
        |> Enum.map(fn {sheet_column, db_column} ->
          {sheet_column, String.to_existing_atom(db_column)}
        end)
        |> Map.new())
    )
    |> Map.new()
  end
end
