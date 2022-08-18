defmodule PicselloWeb.ClientBookingEventLive.Shared do
  @moduledoc """
  functions used by client booking events
  """
  import Phoenix.LiveView
  use Phoenix.Component

  def blurred_thumbnail(assigns) do
    ~H"""
    <div class={"aspect-[3/2] flex items-center justify-center relative overflow-hidden #{@class}"}>
      <div class="absolute inset-0 bg-center bg-cover bg-no-repeat blur-lg" style={"background-image: url('#{@url}')"} />
      <img class="h-full object-cover relative" src={@url} />
    </div>
    """
  end
end
