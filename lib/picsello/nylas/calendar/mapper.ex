defmodule Picsello.NylasCalendar.Mapper do
  @moduledoc "Used to map response getting from calendar api"

  @config Application.compile_env(:picsello, :nylas)
  @base_color @config[:base_color]

  @type calendar_event() :: %{
          color: String.t(),
          end: String.t(),
          start: String.t(),
          title: String.t(),
          other: map()
        }

  @spec to_shoot(map, String.t()) :: calendar_event()
  def to_shoot(
        %{
          "description" => description,
          "location" => location,
          "organizer_email" => organizer_email,
          "organizer_name" => organizer_name,
          "status" => status,
          "title" => title,
          "when" => date_obj
        } = event,
        timezone
      ) do
    {start_date, end_date} = build_dates(date_obj, timezone)

    %{
      title: "#{title}",
      color: @base_color,
      start: start_date,
      end: end_date,
      other: %{
        description: description,
        location: location,
        organizer_email: organizer_email,
        organizer_name: organizer_name,
        conferencing: event["conferencing"],
        status: status,
        calendar: "external"
      }
    }
  end

  def handle_response(%{status_code: 200, body: body}), do: {:ok, Jason.decode!(body)}

  def handle_response(%{status_code: status_code}),
    do: {:error, "Failed request with status code: #{status_code}"}

  def process_token_response(body) do
    case Jason.decode(body) do
      {:ok, %{"access_token" => token}} -> {:ok, token}
      {:ok, _} -> {:error, "Invalid token response"}
      {:error, _} -> {:error, "Failed to decode token response"}
    end
  end

  defp build_dates(%{"date" => date, "object" => "date"}, _timezone) do
    {:ok, start_date} = Date.from_iso8601(date)

    {start_date, start_date}
  end

  defp build_dates(
         %{"start_date" => start_date, "end_date" => end_date, "object" => "datespan"},
         _timezone
       ),
       do: {start_date, end_date}

  defp build_dates(
         %{"start_time" => start_time, "end_time" => end_time, "object" => "timespan"},
         timezone
       ) do
    {from_unix(start_time, timezone), from_unix(end_time, timezone)}
  end

  defp build_dates(
         %{"time" => time, "object" => "time"},
         timezone
       ) do
    {from_unix(time, timezone), from_unix(time, timezone)}
  end

  defp from_unix(time, timezone) do
    time
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!(timezone)
    |> DateTime.to_iso8601()
  end
end
