defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  import PicselloWeb.Live.Calendar.Shared
  @impl true
  @spec mount(any, map, Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"user_token" => token}, socket) do
    user = Accounts.get_user_by_session_token(token)
    {:ok, nylas_url} = NylasCalendar.generate_login_link()

    socket
    |> assign(:nylas_url, nylas_url)
    |> assign(:show_calendar_setup, is_nil(user.nylas_oauth_token))
    |> assign(:page_title, "Calendar")
    |> ok()
  end

  @impl true
  @spec handle_event(String.t(), any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate handle_event(event, params, socket), to: PicselloWeb.Live.Calendar.Shared
end
