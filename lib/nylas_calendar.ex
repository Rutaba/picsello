defmodule NylasCalendar do
  @moduledoc """
  An Elixir module for interacting with the Nylas Calendar API.
  """

  @base_url "https://api.nylas.com"
  @calendar_endpoint "/calendars"
  @events_endpoint "/events"

  @doc """
  Retrieves a list of calendars associated with the authenticated account.
  """
  def get_calendars() do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}"

    response = HTTPoison.get(url, headers)

    case response.status_code do
      200 ->
        {:ok, response.body}

      code ->
        {:error, "Failed to retrieve calendars. Status code: #{code}"}
    end
  end

  @doc """
  Creates a new calendar with the given parameters.
  """
  def create_calendar(params) do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}"

    response = HTTPoison.post(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, response.body}

      code ->
        {:error, "Failed to create calendar. Status code: #{code}"}
    end
  end

  @doc """
  Adds an event to the specified calendar.
  """
  def add_event(calendar_id, params) do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}/#{calendar_id}#{@event_endpoint}"

    response = HTTPoison.post(url, Jason.encode!(params), headers)

    case response.status_code do
      200 ->
        {:ok, response.body}

      code ->
        {:error, "Failed to add event. Status code: #{code}"}
    end
  end

  @doc """
  Retrieves a list of events on the specified calendar.
  """
  def get_events(calendar_id) do
    headers = build_headers()
    url = "#{@base_url}#{@calendar_endpoint}/#{calendar_id}#{@event_endpoint}"

    response = HTTPoison.get(url, headers)

    case response.status_code do
      200 ->
        {:ok, response.body}

      code ->
        {:error, "Failed to retrieve events. Status code: #{code}"}
    end
  end

  defp build_headers() do
    token = Application.get_env(:picsello, :nylas_token)

    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end
end
