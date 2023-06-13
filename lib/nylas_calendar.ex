defmodule NylasCalendar do
  @moduledoc """
  An Elixir module for interacting with the Nylas Calendar API.
  """
  require Logger
  @base_color "#585DF6"
  @base_url "https://api.nylas.com"
  @calendar_endpoint "/calendars"
  @event_endpoint "/events"
  @base_url "https://api.nylas.com"
  @auth_endpoint "/oauth/authorize"
  @type token() :: String.t()
  @type result(x) :: {:ok, x} | {:error, String.t()}
  @spec generate_login_link(any, any) :: {:ok, <<_::64, _::_*8>>}
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

    response = HTTPoison.get!(url, headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to retrieve calendars. Status code: #{code}"}
    end
  end

  @spec create_calendar(any, token()) :: result(any)
  @doc """
  Creates a new calendar with the given parameters.
  """
  def create_calendar(params, token) do
    headers = build_headers(token)
    url = "#{@base_url}#{@calendar_endpoint}"

    response = HTTPoison.post!(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to create calendar. Status code: #{code}"}
    end
  end

  @spec add_event(any, any, token()) :: result(any)
  @doc """
  Adds an event to the specified calendar.
  """
  def add_event(calendar_id, params, token) do
    headers = build_headers(token)
    url = "#{@base_url}/#{@event_endpoint}"

    params = Map.put(params, "calendar_id", calendar_id)
    response = HTTPoison.post!(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to add event. Status code: #{code}"}
    end
  end

  @type calendar_event() :: %{
          color: String.t(),
          end: String.t(),
          start: String.t(),
          title: String.t(),
          url: String.t()
        }
  # def get_events!([],_), do: []
  def get_events!(calendars, token), do: get_events!(calendars, token, "America/New_York")

  @spec get_events!([String.t()], String.t()) :: list(calendar_event())
  def get_events!(nil, _, _), do: []
  def get_events!(_, nil, _), do: []

  def get_events!(calendars, token, timezone) when is_list(calendars) do
    Logger.info("timezone #{timezone} +++++++")

    calendars
    |> Enum.flat_map(fn calendar_id ->
      Logger.info("Get events for #{calendar_id} #{token}")
      {:ok, events} = get_events(calendar_id, token)
      events
    end)
    |> Enum.map(&to_shoot(&1, timezone))
  end

  @spec to_shoot(map, String.t()) :: calendar_event()
  def to_shoot(
        %{
          "description" => _notes,
          "id" => _id,
          "location" => _location,
          "title" => name,
          "when" => %{"date" => date, "object" => "date"}
        },
        _timezone
      ) do
    {:ok, start_time} = Date.from_iso8601(date)
    end_time = start_time |> Date.add(1) |> Date.to_iso8601()
    %{title: "#{name}", color: @base_color, start: date, end: end_time, url: ""}
  end

  def to_shoot(
        %{
          "description" => _notes,
          "id" => id,
          "calendar_id" => calendar_id,
          "location" => _location,
          "title" => name,
          "when" => %{"start_time" => start_time, "end_time" => end_time, "object" => "timespan"}
        } = _c,
        timezone
      ) do
    start = start_time|>DateTime.from_unix!() |> DateTime.shift_zone!(timezone)
    finish = end_time |> DateTime.from_unix!() |> DateTime.shift_zone!(timezone)

    %{
      title: "#{name}",
      color: @base_color,
      start: DateTime.to_iso8601(start),
      end: DateTime.to_iso8601(finish),
      url:
        PicselloWeb.Router.Helpers.remote_path(PicselloWeb.Endpoint, :remote, calendar_id, id, %{
          "request_from" => "calendar"
        })
    }
  end

  @spec get_events(String.t(), token()) :: {:error, <<_::64, _::_*8>>} | {:ok, any}
  @doc """
  Retrieves a list of events on the specified calendar.
  """
  def get_events(calendar_id, token) do
    headers = build_headers(token)

    url = "#{@base_url}#{@event_endpoint}?calendar_id=#{calendar_id}"

    response = HTTPoison.get!(url, headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to retrieve events. Status code: #{code}"}
    end
  end

  def get_event_details(job_id, token) do
    Logger.info("TOKEN #{token} *******")
    headers = build_headers(token)
    url = "#{@base_url}/events/#{job_id}"

    case HTTPoison.get!(url, headers) do
      %{status_code: 200, body: body} ->
        %{
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
        } = Jason.decode!(body)

        {:ok,
         %{
           busy: busy,
           description: description,
           object: object_type,
           owner_email: owner_email,
           participants: participants,
           status: status,
           title: title,
           updated_at: updated_at,
           start_time: start_time,
           end_time: end_time
         }}

      %{status_code: code} ->
        {:error, "Failed to retrieve events. Status code: #{code}"}
    end
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
