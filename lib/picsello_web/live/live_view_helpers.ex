defmodule PicselloWeb.LiveViewHelpers do
  @moduledoc false
  import Phoenix.LiveView
  alias PicselloWeb.LiveAuth

  def assign_defaults(socket, session) do
    case LiveAuth.mount(%{}, session, socket) do
      {:cont, socket} -> socket
      {:halt, socket} -> socket |> assign(:current_user, nil)
    end
  end
end
