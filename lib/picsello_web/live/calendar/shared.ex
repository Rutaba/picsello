defmodule PicselloWeb.Live.Calendar.Shared do
  @moduledoc """
  functions used by calendar components
  """
  import PicselloWeb.LiveHelpers
  import Phoenix.Component

  def back_button(assigns) do
    ~H"""
    <.live_link to={@to} class={"#{@class} rounded-full bg-base-200 flex items-center justify-center p-2.5 mr-4"}>
      <.icon name="back" class="w-4 h-4 stroke-2"/>
    </.live_link>
    """
  end

  def is_checked(id, package) do
    if id do
      id == if(is_binary(id), do: package.id |> Integer.to_string(), else: package.id)
    else
      false
    end
  end

  @spec handle_event(<<_::160>>, any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event(
        "toggle_connect_modal",
        _,
        %Phoenix.LiveView.Socket{assigns: %{nylas_url: nylas_url}} = socket
      ) do
    socket
    |> PicselloWeb.Live.Calendar.Shared.ConnectModal.open(%{nylas_url: nylas_url})
    |> noreply()
  end
end
