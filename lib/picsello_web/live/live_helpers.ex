defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
