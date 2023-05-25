defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  @spec mount(any, map, map) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"user_token" => token}, socket) do
    user = Accounts.get_user_by_session_token(token)
    {:ok, url} = NylasCalendar.generate_login_link()

    socket
    |> assign(:nylas_url, url)
    |> assign(:show_calendar_setup, is_nil(user.nylas_oauth_token))
    |> assign(:page_title, "Calendar")
    |> assign(:connect_modal, Mix.env() == :dev)
    |> ok()
  end

  @impl true
  @spec handle_event(<<_::160>>, any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event(
        "toggle_connect_modal",
        _,
        %Phoenix.LiveView.Socket{assigns: %{connect_modal: connect_modal}} = socket
      ) do
    {:noreply, assign(socket, :connect_modal, not connect_modal)}
  end
end
