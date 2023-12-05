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
     |> assign(:gallery, gallery)
     |> assign(:password, gallery.password)
     |> assign(:is_password, gallery.is_password)
     |> assign(
       :password_changeset,
       Galleries.Gallery.password_changeset(gallery) |> Map.put(:action, :validate)
     )}
  end

  @impl true
  def handle_event("toggle_visibility", _, %{assigns: %{visibility: visibility}} = socket) do
    socket
    |> assign(:visibility, !visibility)
    |> noreply
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["gallery", "is_password"], "gallery" => %{"is_password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    password = String.to_atom(password)

   {:ok, gallery} = Galleries.update_gallery(gallery, %{is_password: password})
    socket
    |> assign(:is_password, password)
    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def handle_event(
        "validate",
        %{"gallery" => %{"password" => password}} = params,
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> assign(:password, password)
    |> assign(
      :password_changeset,
      Galleries.Gallery.password_changeset(gallery, %{password: password})
      |> Map.put(:action, :validate)
    )
    |> noreply
  end

  def handle_event("save", _params, %{assigns: %{gallery: gallery, password: password}} = socket) do
    {:ok, gallery} = Galleries.update_gallery(gallery, %{password: password})
    socket
    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="font-sans">Gallery password</h3>
      <div class="relative">
        <.form :let={f} for={@password_changeset} phx-change="validate" phx-submit="save" phx-target={@myself} >
          <%= error_tag f, :password, class: "text-red-sales-300" %>
          <%= if @visibility do %>
            <%= text_input f, :password, value: @password, disabled: !@is_password, phx_debounce: "500", id: "galleryPasswordInput",
            class: "gallerySettingsInput font-sans" %>
          <% else %>
            <%= password_input f, :password, value: @password, disabled: !@is_password,  phx_debounce: "500", id: "galleryPasswordInput",
            class: "gallerySettingsInput font-sans" %>
          <% end %>
          <a phx-click="toggle_visibility" phx-target={@myself} class=" flex flex-col absolute h-8 -translate-y-1/2 right-5 top-8" id="togglePasswordVisibility">
            <%= if @visibility do %>
              <.icon name="eye" class="w-5 h-full ml-1 text-base-250 cursor-pointer"/>
            <% else %>
              <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250 cursor-pointer"/>
            <% end %>
          </a>

          <div class="flex  items-center justify-between w-full mt-5 lg:items-start">
            <div class="flex items-center">
              <%= checkbox f, :is_password, value: @gallery.is_password, class: "w-6 h-6 mr-3 checkbox-exp cursor-pointer", phx_debounce: 200 %>
              <label class={classes("", %{"text-gray-400 cursor-default" => !@gallery.is_password})}>
                    Include Password
              </label>
            </div>
            <%= submit "Save", class: "btn-settings w-32  px-11", disabled: (@is_password || @password_changeset.valid?) && not (@is_password && @password_changeset.valid?), phx_disable_with: "Saving..." %>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
