defmodule PicselloWeb.GalleryLive.Settings.ManagePasswordComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {:ok,
     socket
     |> assign(:visibility, false)
     |> assign(:id, id)
     |> assign(:gallery, gallery)}
  end

  @impl true
  def handle_event("toggle_visibility", _, %{assigns: %{visibility: visibility}} = socket) do
    socket
    |> assign(:visibility, !visibility)
    |> noreply
  end

  @impl true
  def handle_event("regenerate", _params, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.regenerate_gallery_password(gallery))
    |> noreply
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="font-sans">Gallery password</h3>
      <div class="relative">
        <%= if @visibility do %>
          <%= text_input :gallery, :password, value: @gallery.password, disabled: true, id: "galleryPasswordInput",
          class: "gallerySettingsInput" %>
        <% else %>
          <%= password_input :gallery, :password, value: @gallery.password, disabled: true, id: "galleryPasswordInput",
          class: "gallerySettingsInput" %>
        <% end %>

        <a href="#" phx-click="toggle_visibility" phx-target={@myself} class="absolute h-full -translate-y-1/2 right-5 top-1/2" id="togglePasswordVisibility">
          <%= if @visibility do %>
            <.icon name="eye" class="w-5 h-full ml-1 text-base-250"/>
          <% else %>
            <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250"/>
          <% end %>
        </a>
      </div>
      <div class="flex items-center justify-between w-full mt-5 lg:items-start">
        <button phx-click="regenerate" phx-target={@myself} class="p-4 font-bold cursor-pointer text-blue-planning-300 lg:pt-0" id="regeneratePasswordButton">
            Re-generate
        </button>
        <button id="CopyToClipboardButton" phx-hook="Clipboard" data-clipboard-text={@gallery.password}
        class="py-2 border rounded-lg border-blue-planning-300 text-blue-planning-300 w-36">
        <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
            Copied!
        </div>
          Copy password
        </button>
      </div>
    </div>
    """
  end
end
