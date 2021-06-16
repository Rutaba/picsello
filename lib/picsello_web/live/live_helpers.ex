defmodule PicselloWeb.LiveHelpers do
  @moduledoc false
  import Phoenix.LiveView

  def assign_defaults(socket, %{"user_token" => user_token}) do
    assign_new(socket, :current_user, fn ->
      Picsello.Accounts.get_user_by_session_token(user_token)
    end)
  end

  def assign_defaults(socket, _session) do
    assign_new(socket, :current_user, fn -> nil end)
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
