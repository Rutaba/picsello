defmodule PicselloWeb.Live.Calendar.Shared do
  @moduledoc """
  functions used by calendar components
  """
  import PicselloWeb.LiveHelpers
  import Phoenix.Component

  def back_button(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        icon_dimensions: "w-4 h-4",
        icon_stroke: "stroke-2",
        live_link_padding: "p-2.5",
        live_link_right_padding: "mr-4"
      })

    ~H"""
    <.live_link to={@to} class={"#{@class} rounded-full bg-base-200 flex items-center justify-center #{@live_link_padding} #{@live_link_right_padding}"}>
      <.icon name="back" class={"#{@icon_dimensions} #{@icon_stroke}"}/>
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
end
