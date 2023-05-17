defmodule NylasCalendar do
  @moduledoc """
  An Elixir module for interacting with the Nylas Calendar API.
  """

  @base_url "https://api.nylas.com"
  @calendar_endpoint "/calendars"
  @event_endpoint "/events"
  @type result(x) :: {:ok, x} | {:error, String.t()}
  @spec get_calendars :: result([map()])
  @doc """
  Retrieves a list of calendars associated with the authenticated account.
  """
  def get_calendars() do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}"

    response = HTTPoison.get!(url, headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to retrieve calendars. Status code: #{code}"}
    end
  end

  @spec create_calendar(any) :: result(any)
  @doc """
  Creates a new calendar with the given parameters.
  """
  def create_calendar(params) do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}"

    response = HTTPoison.post!(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to create calendar. Status code: #{code}"}
    end
  end

  @spec add_event(any, any) :: result(any)
  @doc """
  Adds an event to the specified calendar.
  """
  def add_event(calendar_id, params) do
    headers = build_headers()
    url = "#{@base_url}/#{@event_endpoint}"

    params = Map.put(params, "calendar_id", calendar_id)
    response = HTTPoison.post!(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        IO.inspect(response)
        {:error, "Failed to add event. Status code: #{code}"}
    end
  end

  @spec get_events(any) :: {:error, <<_::64, _::_*8>>} | {:ok, any}
  @doc """
  Retrieves a list of events on the specified calendar.
  """
  def get_events(calendar_id) do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}/#{calendar_id}#{@event_endpoint}"

    response = HTTPoison.get!(url, headers)

    case response.status_code do
      200 ->
        {:ok, Jason.decode!(response.body)}

      code ->
        {:error, "Failed to retrieve events. Status code: #{code}"}
    end
  end

  defp build_headers() do
    %{client_id: _client_id, client_secret: _secret, token: token} =
      Application.get_env(:picsello, :nylas)

    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end
end
