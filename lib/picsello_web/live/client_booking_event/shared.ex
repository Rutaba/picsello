defmodule PicselloWeb.ClientBookingEventLive.Shared do
  @moduledoc """
  functions used by client booking events
  """
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component
  import PicselloWeb.Gettext, only: [dyn_gettext: 1]

  def blurred_thumbnail(assigns) do
    ~H"""
    <div class={"aspect-[3/2] flex items-center justify-center relative overflow-hidden #{@class}"}>
      <div class="absolute inset-0 bg-center bg-cover bg-no-repeat blur-lg" style={"background-image: url('#{@url}')"} />
      <img class="h-full object-cover relative" src={@url} />
    </div>
    """
  end

  def date_display(assigns) do
    ~H"""
    <div class="flex items-center">
      <.icon name="calendar" class="w-5 h-5 text-black" />
      <span class="ml-2 pt-1"><%= @date %></span>
    </div>
    """
  end

  def address_display(assigns) do
    ~H"""
    <div class={"flex items-center #{@class}"}>
      <.icon name="pin" class="w-5 h-5 text-black" />
      <span class="ml-2 pt-1"><%= @booking_event.address %></span>
    </div>
    """
  end

  def subtitle_display(assigns) do
    ~H"""
    <p class={@class}><%= formatted_subtitle(@booking_event, @package) %></p>
    """
  end

  def formatted_date(booking_event) do
    dates =
      booking_event
      |> Map.get(:dates)
      |> Enum.sort_by(& &1.date, Date)
      |> Enum.map(& &1.date)
      |> Enum.map(&Calendar.strftime(&1, "%b %d, %Y"))

    [
      Enum.at(dates, 0),
      Enum.at(dates, -1)
    ]
    |> Enum.uniq()
    |> Enum.join(" - ")
  end

  defp formatted_subtitle(booking_event, package) do
    [
      if(package.download_count > 0,
        do: "#{package.download_count} images include"
      ),
      "#{booking_event.duration_minutes} min session",
      dyn_gettext(booking_event.location)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" | ")
  end
end
