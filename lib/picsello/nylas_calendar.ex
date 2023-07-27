defmodule Picsello.NylasCalendar do
  @moduledoc """

  An Elixir module for interacting with the Nylas Calendar
  API. Contains code to get a list of calendars, get events, add
  events to remote calendars etc


  """

  require Logger
  @auth_endpoint "/oauth/authorize"
  @base_color "#585DF6"
  @base_url "https://api.nylas.com"
  @calendar_endpoint "/calendars"
  @event_endpoint "events"

  @type token() :: String.t()
  @type result(x) :: {:ok, x} | {:error, String.t()}

  @spec generate_login_link(String.t(), String.t()) :: {:ok, String.t()}
  @doc """
  Generates a login link for the Nylas API.
  """
  def generate_login_link(client_id, redirect_uri) do
    params =
      URI.encode_query(%{
        client_id: client_id,
        response_type: "code",
        redirect_uri: redirect_uri,
        scopes: "calendar"
      })

    url = "#{@base_url}#{@auth_endpoint}?#{params}"

    {:ok, url}
  end

  @spec generate_login_link() :: {:ok, String.t()}
  def generate_login_link() do
    %{client_id: client_id, redirect_uri: redirect} = Application.get_env(:picsello, :nylas)
    generate_login_link(client_id, redirect)
  end

  @spec get_calendars(token()) :: result([map()])
  @doc """
  Retrieves a list of calendars associated with the authenticated account.
  """
  def get_calendars(token) do
    headers = build_headers(token)
    url = "#{@base_url}#{@calendar_endpoint}"

    url
    |> HTTPoison.get!(headers)
    |> build_response
  end

  @spec create_calendar(map(), token()) :: result(map())
  @doc """
  Creates a new calendar with the given parameters.
  """
  def create_calendar(params, token) do
    headers = build_headers(token)
    url = "#{@base_url}#{@calendar_endpoint}"

    url
    |> HTTPoison.post!(Jason.encode!(params), headers)
    |> build_response()
  end

  @spec get_event_details(String.t(), String.t()) :: result(any())
  @doc """
  Retrieve complete details against event
  """
  def get_event_details(event_id, token) do
    headers = build_headers(token)
    url = "#{@base_url}/events/#{event_id}"

    url
    |> HTTPoison.get!(headers)
    |> build_response()
    |> case do
      {:ok, body} -> convert_remote_to_calendar(body)
      error -> error
    end
  end

  @spec create_event(map(), token()) :: result(any)
  @doc """
  Creates an event to the specified calendar.
  """
  def create_event(%{calendar_id: _} = params, token) do
    headers = build_headers(token)
    url = "#{@base_url}/#{@event_endpoint}"

    params
    |> Jason.encode!()
    |> then(&HTTPoison.post!(url, &1, headers))
    |> build_response()
  end

  @spec update_event(map(), token()) :: result(any)
  @doc """
  Update an event using its id.
  """
  def update_event(%{id: event_id} = params, token) do
    headers = build_headers(token)
    url = "https://api.nylas.com/events/#{event_id}?notify_participants=true"

    url
    |> HTTPoison.put!(Jason.encode!(params), headers)
    |> build_response()
  end

  @spec delete_event(String.t(), String.t()) :: result(map())
  @doc """
  Delete an event using its id.
  """
  def delete_event(event_id, token) do
    headers = build_headers(token)
    url = "https://api.nylas.com/events/#{event_id}?notify_participants=true  "

    url
    |> HTTPoison.delete!(headers)
    |> build_response()
  end

  @type calendar_event() :: %{
          color: String.t(),
          end: String.t(),
          start: String.t(),
          title: String.t(),
          other: map()
        }

  @spec get_external_events(list(String.t()), String.t(), String.t()) :: list(calendar_event())
  @doc """
  Retrive all events of given calendars that don't belong to Picsello
  """
  @timezone "America/New_York"
  def get_external_events(calendars, token, timezone \\ @timezone),
    do: filter_events(calendars, token, timezone, &remove_picsello/1)

  @spec get_picsello_events(list(String.t()), String.t(), String.t()) :: list(calendar_event())
  @doc """
  Retrive all events of given calendars that belong to Picsello
  """
  def get_picsello_events(calendars, token, timezone \\ @timezone),
    do: filter_events(calendars, token, timezone, &only_picsello/1)

  @spec get_events(String.t(), token()) :: {:error, String.t()} | {:ok, any}
  @doc """
  Retrieves a list of events on the specified calendar.
  """
  def get_events(calendar_id, token) do
    headers = build_headers(token)

    url = "#{@base_url}/#{@event_endpoint}?calendar_id=#{calendar_id}"

    url
    |> HTTPoison.get!(headers)
    |> build_response()
  end

  @spec fetch_token(token()) :: result(token())
  def fetch_token(code) do
    %{client_id: client_id, client_secret: client_secret, redirect_uri: redirect_uri} =
      Application.get_env(:picsello, :nylas)

    url = "https://api.nylas.com/oauth/token"

    body = %{
      grant_type: "authorization_code",
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    }

    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %{body: body}} -> process_token_response(body)
      {:error, error} -> {:error, "Failed to fetch OAuth token: #{error}"}
    end
  end

  # get and filter events using given filter function.
  defp filter_events(calendars, token, timezone, filter_fn) when is_list(calendars) do
    calendars
    |> Enum.flat_map(fn calendar_id ->
      Logger.debug("Get events for #{calendar_id} #{token}")
      {:ok, events} = get_events(calendar_id, token)
      events
    end)
    |> Enum.filter(filter_fn)
    |> Enum.map(&to_shoot(&1, timezone))
  end

  @picsello_tag "[From Picsello]"
  @spec remove_picsello(map) :: boolean
  defp remove_picsello(%{"description" => nil}), do: true
  defp remove_picsello(%{"description" => des}), do: not (des =~ @picsello_tag)

  defp only_picsello(%{"description" => nil}), do: false
  defp only_picsello(%{"description" => des}), do: des =~ @picsello_tag

  @spec to_shoot(map, String.t()) :: calendar_event()
  defp to_shoot(
         %{
           "description" => description,
           "id" => id,
           "calendar_id" => calendar_id,
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
        calendar: "external",
        url:
          PicselloWeb.Router.Helpers.remote_path(
            PicselloWeb.Endpoint,
            :remote,
            calendar_id,
            id,
            %{"request_from" => "calendar"}
          )
      }
    }
  end

  defp build_dates(%{"date" => date, "object" => "date"}, _timezone) do
    {:ok, start_date} = Date.from_iso8601(date)

    {start_date, start_date |> Date.add(1) |> Date.to_iso8601()}
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
    build = fn time ->
      time
      |> DateTime.from_unix!()
      |> DateTime.shift_zone!(timezone)
      |> DateTime.to_iso8601()
    end

    {build.(start_time), build.(end_time)}
  end

  defp convert_remote_to_calendar(%{
         "busy" => busy,
         "description" => description,
         "object" => object_type,
         "organizer_email" => owner_email,
         "participants" => participants,
         "status" => status,
         "title" => title,
         "updated_at" => updated_at,
         "when" => %{
           "end_time" => end_time,
           "start_time" => start_time
         }
       }) do
    {:ok,
     %{
       busy: busy,
       description: description,
       object: object_type,
       owner_email: owner_email,
       participants: participants,
       status: status,
       title: title,
       updated_at: DateTime.from_unix!(updated_at),
       start_time: DateTime.from_unix!(start_time),
       end_time: DateTime.from_unix!(end_time),
       type: :time
     }}
  end

  defp convert_remote_to_calendar(%{
         "busy" => busy,
         "description" => description,
         "object" => object_type,
         "organizer_email" => owner_email,
         "participants" => participants,
         "status" => status,
         "title" => title,
         "updated_at" => updated_at,
         "when" => %{
           "date" => date,
           "object" => "date"
         }
       }) do
    {:ok,
     %{
       busy: busy,
       description: description,
       object: object_type,
       owner_email: owner_email,
       participants: participants,
       status: status,
       title: title,
       updated_at: DateTime.from_unix!(updated_at),
       date: date,
       type: :date
     }}
  end

  defp build_response(%{status_code: status_code, body: body}) do
    case status_code do
      200 ->
        {:ok, Jason.decode!(body)}

      status_code ->
        {:error, "Failed request with status code: #{status_code}"}
    end
  end

  defp process_token_response(body) do
    case Jason.decode(body) do
      {:ok, %{"access_token" => token}} -> {:ok, token}
      {:ok, _} -> {:error, "Invalid token response"}
      {:error, _} -> {:error, "Failed to decode token response"}
    end
  end

  defp build_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end
end
