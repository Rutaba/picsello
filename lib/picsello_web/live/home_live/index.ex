defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    user_token = Map.get(session, "user_token")
    user = Picsello.Accounts.get_user_by_session_token(user_token)
    {:ok, assign(socket, :user, user)}
  end
end
