defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Jobs, Shoots, NylasCalendar, Repo}
  import PicselloWeb.Live.Calendar.Shared
  alias PicselloWeb.Shared.PopupComponent
  alias PicselloWeb.Calendar.Shared.DetailComponent

  @impl true
  @spec mount(any, map, Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(
        _params,
        _session,
        %{assigns: %{current_user: %{nylas_detail: nylas_detail}}} = socket
      ) do
    {:ok, nylas_url} = NylasCalendar.generate_login_link()

    socket
    |> assign(:nylas_url, nylas_url)
    |> assign(:show_calendar_setup, is_nil(nylas_detail.oauth_token))
    |> assign(:page_title, "Calendar")
    |> assign(:footer_class, nil)
    |> ok()
  end

  @impl true
  def handle_event("event-detail", %{"event" => %{"extendedProps" => props} = event}, socket) do
    socket
    |> PopupComponent.open(%{
      module_component: DetailComponent,
      confirm_event: "open-event",
      title: event["title"],
      opts:
        props
        |> build_opts()
        |> Map.merge(%{
          start_date: build_datetime(event["start"]),
          end_date: build_datetime(event["end"] || event["start"]),
          url: props["other"]["url"]
        })
    })
    |> noreply()
  end

  defdelegate handle_event(event, params, socket), to: PicselloWeb.Live.Calendar.Shared

  defp build_opts(%{"other" => %{"calendar" => "external"} = other}) do
    %{
      calender: "external",
      location: other["location"],
      conferencing: other["conferencing"],
      description: other["description"],
      organizer_email: other["organizer_email"],
      status: other["status"]
    }
  end

  defp build_opts(%{"other" => %{"calendar" => "internal", "job_id" => job_id}}) do
    shoot = Shoots.get_latest_shoot(job_id) || %{}
    %{client: client} = job_id |> Jobs.get_job_by_id() |> Repo.preload(:client)

    %{
      calender: "internal",
      location: Map.get(shoot, :location),
      address: Map.get(shoot, :address),
      client_name: client.name,
      client_phone: client.phone
    }
  end

  defp build_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:error, :invalid_format} ->
        {:ok, %Date{} = date} = Date.from_iso8601(value)
        date

      {:ok, datetime, diff} ->
        DateTime.add(datetime, diff, :second)
    end
  end
end
