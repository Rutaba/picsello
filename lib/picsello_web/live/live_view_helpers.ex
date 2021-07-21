defmodule PicselloWeb.LiveViewHelpers do
  @moduledoc false
  import Phoenix.LiveView

  def assign_defaults(socket, %{"user_token" => user_token}) do
    socket
    |> allow_sandbox()
    |> assign_new(:current_user, fn ->
      Picsello.Accounts.get_user_by_session_token(user_token)
    end)
  end

  def assign_defaults(socket, _session) do
    socket |> allow_sandbox() |> assign_new(:current_user, fn -> nil end)
  end

  defp allow_sandbox(socket) do
    with sandbox when sandbox != nil <- Application.get_env(:picsello, :sandbox),
         true <- connected?(socket),
         metadata when is_binary(metadata) <- get_connect_info(socket)[:user_agent] do
      sandbox.allow(metadata, self())
    end

    socket
  end
end
