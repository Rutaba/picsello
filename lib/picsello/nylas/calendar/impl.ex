defmodule Picsello.NylasCalendar.Impl do
  @moduledoc """
  An Elixir module for interacting with the Nylas Calendar
  API. Contains code to get a list of calendars, get events, add
  events to remote calendars etc
  """

  require Logger
  alias Picsello.NylasCalendar
  alias Picsello.NylasCalendar.Mapper

  @behaviour NylasCalendar

  @config Application.compile_env(:picsello, :nylas)
  @base_url @config[:base_url]
  @picsello_tag @config[:picsello_tag]

  @type token() :: String.t()
  @type result(x) :: {:ok, x} | {:error, String.t()}

  @spec generate_login_link(String.t(), String.t()) :: {:ok, String.t()}
  @doc """
  Generates a login link for the Nylas API.
  """
  @impl NylasCalendar
  def generate_login_link(client_id, redirect_uri) do
    params =
      URI.encode_query(%{
        client_id: client_id,
        response_type: "code",
        redirect_uri: redirect_uri,
        scopes: "calendar"
      })

    {:ok, "#{@base_url}/oauth/authorize?#{params}"}
  end

  @spec generate_login_link() :: {:ok, String.t()}
  @impl NylasCalendar
  def generate_login_link() do
    %{client_id: client_id, redirect_uri: redirect} = config()
    generate_login_link(client_id, redirect)
  end

  @spec get_calendars(token()) :: result([map()])
  @doc """
  Retrieves a list of calendars associated with the authenticated account.
  """
  @impl NylasCalendar
  def get_calendars(token) do
    headers = build_headers(token)
    url = "#{@base_url}/calendars"

    url
    |> HTTPoison.get!(headers)
    |> Mapper.handle_response()
  end

  @spec create_calendar(map(), token()) :: result(map())
  @doc """
  Creates a new calendar with the given parameters.
  """
  @impl NylasCalendar
  def create_calendar(params, token) do
    headers = build_headers(token)
    url = "#{@base_url}/calendars"

    url
    |> HTTPoison.post!(Jason.encode!(params), headers)
    |> Mapper.handle_response()
  end

  @spec create_event(map(), token()) :: result(any)
  @doc """
  Creates an event to the specified calendar.
  """
  @impl NylasCalendar
  def create_event(%{calendar_id: _} = params, token) do
    headers = build_headers(token)
    url = "#{@base_url}/events"

    params
    |> Jason.encode!()
    |> then(&HTTPoison.post!(url, &1, headers))
    |> Mapper.handle_response()
  end

  @spec update_event(map(), token()) :: result(any)
  @doc """
  Update an event using its id.
  """
  @impl NylasCalendar
  def update_event(%{id: event_id} = params, token) do
    headers = build_headers(token)
    url = "#{@base_url}/events/#{event_id}?notify_participants=true"

    url
    |> HTTPoison.put!(Jason.encode!(params), headers)
    |> Mapper.handle_response()
  end

  @spec delete_event(String.t(), String.t()) :: result(map())
  @doc """
  Delete an event using its id.
  """
  @impl NylasCalendar
  def delete_event(event_id, token) do
    headers = build_headers(token)
    url = "#{@base_url}/events/#{event_id}?notify_participants=true"

    url
    |> HTTPoison.delete!(headers)
    |> Mapper.handle_response()
  end

  @type calendar_event() :: %{
          color: String.t(),
          end: String.t(),
          start: String.t(),
          title: String.t(),
          other: map()
        }

  @spec get_external_events(list(String.t()), String.t(), tuple(), String.t()) ::
          list(calendar_event())
  @doc """
  Retrive all events of given calendars that don't belong to Picsello
  """
  @timezone "America/New_York"
  @impl NylasCalendar
  def get_external_events(calendars, token, datetimes, timezone \\ @timezone),
    do: filter_events(calendars, token, timezone, &remove_picsello/1, datetimes)

  @spec get_picsello_events(list(String.t()), String.t(), String.t()) :: list(calendar_event())
  @doc """
  Retrive all events of given calendars that belong to Picsello
  """
  @impl NylasCalendar
  def get_picsello_events(calendars, token, timezone \\ @timezone),
    do: filter_events(calendars, token, timezone, &only_picsello/1)

  @spec get_events(String.t(), token(), tuple() | nil) :: {:error, String.t()} | {:ok, any}
  @doc """
  Retrieves a list of events on the specified calendar.
  """
  @timeout 15_000
  @impl NylasCalendar
  def get_events(calendar_id, token, datetimes) do
    headers = build_headers(token)

    calendar_id
    |> get_events_url(datetimes)
    |> HTTPoison.get!(headers, timeout: @timeout, recv_timeout: @timeout)
    |> Mapper.handle_response()
  end

  @spec fetch_token(token()) :: result(token())
  @impl NylasCalendar
  def fetch_token(code) do
    %{client_id: client_id, client_secret: client_secret, redirect_uri: redirect_uri} = config()

    url = "#{@base_url}/oauth/token"

    body = %{
      grant_type: "authorization_code",
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    }

    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %{body: body}} -> Mapper.process_token_response(body)
      {:error, error} -> {:error, "Failed to fetch OAuth token: #{error}"}
    end
  end

  # get and filter events using given filter function.
  defp filter_events(calendars, token, timezone, filter_fn, datetimes \\ nil)
  defp filter_events(nil, _, _, _, _), do: []
  defp filter_events(_, nil, _, _, _), do: []

  defp filter_events(calendars, token, timezone, filter_fn, datetimes)
       when is_list(calendars) do
    calendars
    |> Task.async_stream(fn calendar_id ->
      Logger.debug("Get events for #{calendar_id} #{token}")
      {:ok, events} = get_events(calendar_id, token, datetimes)
      events
    end)
    |> Enum.reduce([], fn {:ok, events}, acc -> events ++ acc end)
    |> Enum.filter(filter_fn)
    |> Enum.map(&Mapper.to_shoot(&1, timezone))
  end

  @spec remove_picsello(map) :: boolean
  defp remove_picsello(%{"description" => nil}), do: true
  defp remove_picsello(%{"description" => des}), do: not (des =~ @picsello_tag)

  defp only_picsello(%{"description" => nil}), do: false
  defp only_picsello(%{"description" => des}), do: des =~ @picsello_tag

  defp build_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp get_events_url(calendar_id, {starttime, endtime}) do
    "#{get_events_url(calendar_id, nil)}&starts_after=#{starttime}&ends_before=#{endtime}"
  end

  defp get_events_url(calendar_id, _),
    do: "#{@base_url}/events?calendar_id=#{calendar_id}&limit=1000&expand_recurring=true"

  defp config() do
    %{redirect_uri: redirect} = config = @config

    %{config | redirect_uri: PicselloWeb.Endpoint.url() <> redirect}
  end
end
