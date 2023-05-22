defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  @spec mount(any, map, map) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"user_token" => token}, socket) do
    user = Accounts.get_user_by_session_token(token)

    socket
    |> assign(:show_calendar_setup, is_nil(user.nylas_oauth_token))
    |> assign(:page_title, "Calendar")
    |> ok()
  end
end
