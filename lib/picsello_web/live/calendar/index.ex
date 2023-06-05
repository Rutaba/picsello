defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  import PicselloWeb.Live.Calendar.Shared
  @impl true
  @spec mount(any, map, map) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"user_token" => token}, %{assigns: %{current_user: user}} = socket) do
    user = Accounts.get_user_by_session_token(token)
    {:ok, nylas_url} = NylasCalendar.generate_login_link()

    socket
    |> assign(:nylas_url, nylas_url)
    |> assign(:show_calendar_setup, is_nil(user.nylas_oauth_token))
    |> assign(:page_title, "Calendar")
    |> ok()
  end

  @impl true
  defdelegate handle_event(event, params, socket), to: PicselloWeb.Live.Calendar.Shared
end
