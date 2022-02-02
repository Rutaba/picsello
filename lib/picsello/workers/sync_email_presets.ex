defmodule Picsello.Workers.SyncEmailPresets do
  @moduledoc "fetches email preset content from google sheet"
  require Logger

  use Oban.Worker, queue: :default

  alias GoogleApi.Sheets.V4, as: Sheets
  alias Picsello.{Repo, EmailPreset}
  import Ecto.Query, only: [from: 2]

  @sheet_id "1nGpqihCY7wbhE3J7VJecu_eOQ1A7PSMIWZGfGdRq70c"

  @type_range %{
    "wedding" => "Wedding!A2:E20",
    "family" => "Family!A2:E19",
    "headshot" => "Headshot!A2:E19",
    "newborn" => "Newborn!A2:E19",
    "portrait" => "Portrait!A2:E19",
    "boudoir" => "Boudoir!A2:E19",
    "event" => "Event!A2:E19",
    "mini" => "Mini Session!A2:E19",
    "maternity" => "Maternity!A2:E19"
  }

  @sheet_column_db_column %{
    "state" => :job_state,
    "subject lines" => :subject_template,
    "copy" => :body_template,
    "email template name" => :name
  }

  def perform(_) do
    {:ok, %{token: token}} =
      Goth.Token.for_scope("https://www.googleapis.com/auth/spreadsheets.readonly")

    connection = Sheets.Connection.new(token)

    now = DateTime.truncate(DateTime.utc_now(), :second)

    rows =
      @type_range
      |> Enum.map(&fetch_sheet(&1, connection))
      |> Enum.concat()
      |> Enum.map(&Map.merge(&1, %{updated_at: now, inserted_at: now}))

    Repo.transaction(fn ->
      job_types = Picsello.JobType.all()

      rows = Enum.filter(rows, &Enum.member?(job_types, Map.get(&1, :job_type)))

      {_count, presets} =
        Repo.insert_all(EmailPreset, rows,
          on_conflict: {:replace, ~w[subject_template body_template]a},
          conflict_target: ~w[job_state job_type name]a,
          returning: [:id]
        )

      ids = Enum.map(presets, &Map.get(&1, :id))

      from(preset in EmailPreset, where: preset.id not in ^ids)
      |> Repo.delete_all()
    end)
  end

  defp fetch_sheet({type, range}, connection) do
    {:ok, %{values: [keys | rows]}} =
      Sheets.Api.Spreadsheets.sheets_spreadsheets_values_get(connection, @sheet_id, range)

    keys =
      for(
        key <- trim_all(keys),
        do: Map.get(@sheet_column_db_column, String.downcase(key), key)
      )

    rows
    |> Enum.reduce(
      [],
      fn row, acc ->
        try do
          [
            keys
            |> Enum.zip(trim_all(row))
            |> Enum.into(%{job_type: type})
            |> Map.take([:job_type | Map.values(@sheet_column_db_column)])
            |> Map.update!(:name, &Regex.replace(~r/^DEFAULT\s*-\s*/, &1, ""))
            |> Map.update!(
              :job_state,
              &(&1
                |> String.downcase()
                |> String.replace(~r/\s+/, "_")
                |> String.to_existing_atom())
            )
            | acc
          ]
        rescue
          e ->
            Logger.warn("skipping row #{row} because #{inspect(e)}")
            acc
        end
      end
    )
  end

  defp trim_all(list), do: Enum.map(list, &String.trim/1)
end
