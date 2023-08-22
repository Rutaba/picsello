defmodule Picsello.NylasCalendar do
  @timezone "America/New_York"

  @moduledoc "behavior of calendar"

  @callback generate_login_link(integer(), String.t()) ::
              {:ok, String.t()}

  @callback generate_login_link() ::
              {:ok, String.t()}

  @callback get_calendars(String.t()) :: {:ok, [map]} | {:error, String.t()}

  @callback create_calendar(map(), String.t()) :: {:ok, map} | {:error, String.t()}

  @callback create_event(map(), String.t()) :: {:ok, any()} | {:error, String.t()}

  @callback update_event(map(), String.t()) :: {:ok, any()} | {:error, String.t()}

  @callback delete_event(String.t(), String.t()) :: {:ok, any()} | {:error, String.t()}

  @callback get_external_events(list(String.t()), String.t(), String.t()) ::
              list(%{
                color: String.t(),
                end: String.t(),
                start: String.t(),
                title: String.t(),
                other: map()
              })

  @callback get_picsello_events(list(String.t()), String.t(), String.t()) ::
              list(%{
                color: String.t(),
                end: String.t(),
                start: String.t(),
                title: String.t(),
                other: map()
              })

  @callback get_events(String.t(), String.t()) :: {:error, String.t()} | {:ok, any}

  @callback fetch_token(String.t()) :: {:ok, String.t()} | {:error, String.t()}

  def generate_login_link(id, url), do: impl().generate_login_link(id, url)

  def generate_login_link(), do: impl().generate_login_link()
  def get_calendars(token), do: impl().get_calendars(token)
  def create_calendar(params, token), do: impl().create_calendar(params, token)
  def create_event(params, token), do: impl().create_event(params, token)
  def update_event(params, token), do: impl().update_event(params, token)

  def delete_event(event_id, token),
    do: impl().delete_event(event_id, token)

  def get_external_events(calendars, token, timezone \\ @timezone) do
    impl().get_external_events(calendars, token, timezone)
  end

  def get_picsello_events(calendars, token, timezone \\ @timezone),
    do: impl().get_picsello_events(calendars, token, timezone)

  def get_events(calendar_id, token), do: impl().get_events(calendar_id, token)
  def fetch_token(code), do: impl().fetch_token(code)

  defp impl, do: Application.get_env(:picsello, :nylas_calendar)
end
