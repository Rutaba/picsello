defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view

  alias PicselloWeb.Endpoint
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  @spec mount(
          map(),
          map(),
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    url = Routes.i_calendar_url(socket, :index, Phoenix.Token.sign(Endpoint, "USER_ID", user.id))

    socket
    |> assign(url: url)
    |> ok()
  end
end
