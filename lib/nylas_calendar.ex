defmodule NylasCalendar do
  @moduledoc """
  An Elixir module for interacting with the Nylas Calendar API.
  """
  require Logger
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

  # def get_events!([],_), do: []
  def get_events!(nil, _), do: []
  def get_events!(_, nil), do: []

  def get_events!(calendars, token) when is_list(calendars) do
    IO.inspect(calendars)

    calendars
    |> Enum.flat_map(fn calendar_id ->
      {:ok, events} = get_events(calendar_id, token)

      if length(events) > 0 do
        Logger.debug("Events #{inspect(hd(events), pretty: true)}")
      end

      events
    end)
    |> Enum.map(&to_shoot/1)
  end

  @spec to_shoot(map) :: %{
          color: <<_::32>>,
          end: binary,
          start: binary,
          title: <<_::24, _::_*8>>,
          url: <<>>
        }
  def to_shoot(
        %{
          "description" => notes,
          "id" => id,
          "location" => _location,
          "title" => name,
          "when" => %{"date" => date, "object" => "date"}
        } = json
      ) do
    {:ok, start_time} = Date.from_iso8601(date)
    end_time = start_time |> Date.add(1) |> Date.to_iso8601()
    %{title: "#{name}", color: "blue", start: date, end: end_time, url: ""}
  end

  def to_shoot(%{
        "description" => notes,
        "id" => id,
        "location" => _location,
        "title" => name,
        "when" => %{"start_time" => start_time, "end_time" => end_time, "object" => "timespan"}
      }) do
    start = DateTime.from_unix!(start_time)
    finish = DateTime.from_unix!(end_time)

    %{
      title: "#{name}",
      color: "blue",
      start: DateTime.to_iso8601(start),
      end: DateTime.to_iso8601(finish),
      url: ""
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

  # %{
  #   "account_id" => "92kk7fha5ii4aiy4swl74kdeb",
  #   "busy" => false,
  #   "calendar_id" => "o6wzom3li5lk2i72kaia5pmj",
  #   "customer_event_id" => nil,
  #   "description" => nil,
  #   "hide_participants" => false,
  #   "ical_uid" => "20230519_hju6bvukllsfb6gl70sfih689c@google.com",
  #   "id" => "7u5oh1xxj62s0hghf8j2i5f7s",
  #   "location" => nil,
  #   "message_id" => nil,
  #   "object" => "event",
  #   "organizer_email" => "en.judaism#holiday@group.v.calendar.google.com",
  #   "organizer_name" => "Jewish Holidays",
  #   "owner" => "Jewish Holidays <en.judaism#holiday@group.v.calendar.google.com>",
  #   "participants" => [],
  #   "read_only" => true,
  #   "reminders" => nil,
  #   "status" => "confirmed",
  #   "title" => "Jerusalem Day",
  #   "updated_at" => 1684505908,
  #   "visibility" => "public",
  #   "when" => %{"date" => "2023-05-19", "object" => "date"}
  # }

  def map_data_to_internal_format(_) do
  end
end
