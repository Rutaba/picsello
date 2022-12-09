defmodule PicselloWeb.GalleryLive.Photos.Photo.Shared do
  @moduledoc "Shared function among client and photographer photo component"

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  def js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end

  def photo(%{target: false} = assigns) do
    ~H"""
    <img src={@url} class="relative" />
    """
  end

  def photo(assigns) do
    ~H"""
    <img phx-click="click" phx-target={@target} phx-value-preview={@preview} phx-value-preview_photo_id={@photo_id} src={@url} class="relative" />
    """
  end
end
