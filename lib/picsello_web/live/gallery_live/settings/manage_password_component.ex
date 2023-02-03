defmodule PicselloWeb.GalleryLive.Settings.ManagePasswordComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  import PicselloWeb.GalleryLive.Shared, only: [disabled?: 1]

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
          class: "gallerySettingsInput font-sans" %>
        <% else %>
          <%= password_input :gallery, :password, value: @gallery.password, disabled: true, id: "galleryPasswordInput",
          class: "gallerySettingsInput font-sans" %>
        <% end %>

        <a phx-click="toggle_visibility" phx-target={@myself} class="absolute h-full -translate-y-1/2 right-5 top-1/2" id="togglePasswordVisibility">
          <%= if @visibility do %>
            <.icon name="eye" class="w-5 h-full ml-1 text-base-250 cursor-pointer"/>
          <% else %>
            <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250 cursor-pointer"/>
          <% end %>
        </a>
      </div>
      <div {testid("password_component")} class="flex items-center justify-between w-full mt-3 lg:items-start">
        <button phx-click="regenerate" disabled={disabled?(@gallery)} phx-target={@myself} class={classes("p-4 font-bold font-sans cursor-pointer text-blue-planning-300 lg:pt-0", %{"text-gray-200" => disabled?(@gallery)})} id="regeneratePasswordButton">
            Re-generate
        </button>
        <button disabled={disabled?(@gallery)} id="CopyToClipboardButton" phx-hook="Clipboard" data-clipboard-text={@gallery.password}
        class={classes("py-2 border rounded-lg border-blue-planning-300 text-blue-planning-300 w-36 mt-2", %{"border-gray-200 text-gray-200" => disabled?(@gallery)})}>
        <div class="hidden p-1 text-sm rounded font-sans shadow bg-white" role="tooltip">
            Copied!
        </div>
          Copy password
        </button>
      </div>
    </div>
    """
  end
end
