defmodule PicselloWeb.Live.Calendar.Shared do
  @moduledoc """
  functions used by calendar components
  """
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component

  def back_button(assigns) do
    ~H"""
    <.live_link to={@to} class={"#{@class} rounded-full bg-base-200 flex items-center justify-center p-2.5 mr-4"}>
      <.icon name="back" class="w-4 h-4 stroke-2"/>
    </.live_link>
    """
  end
end
