defmodule PicselloWeb.LiveHelpers do
  @moduledoc false
  import Phoenix.LiveView

  def assign_defaults(socket, %{"user_token" => user_token}) do
    socket
    |> allow_ecto_sandbox()
    |> assign_new(:current_user, fn ->
      Picsello.Accounts.get_user_by_session_token(user_token)
    end)
  end

  def assign_defaults(socket, _session) do
    socket |> allow_ecto_sandbox() |> assign_new(:current_user, fn -> nil end)
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}

  defp allow_ecto_sandbox(socket) do
    with true <- Application.get_env(:picsello, :sql_sandbox),
         true <- connected?(socket),
         metadata when is_binary(metadata) <- get_connect_info(socket)[:user_agent],
         %{owner: owner, repo: [repo]} <- Phoenix.Ecto.SQL.Sandbox.decode_metadata(metadata) do
      Ecto.Adapters.SQL.Sandbox.allow(repo, owner, self())
    end

    socket
  end
end
