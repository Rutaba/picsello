defmodule PicselloWeb.Shared.ImageUploadInput do
  @moduledoc """
    Helper functions to use the image upload input component
  """
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        id: "image-upload-input",
        class: "",
        resize_height: 650,
        uploading: false,
        supports: "Supports JPEG or PNG: 1060x650 under 10mb",
        url: nil
      })

    ~H"""
    <div id={"#{@id}-wrapper"} class={@class} phx-hook="ImageUploadInput" class="mt-2" data-target={@myself} data-upload-folder={@upload_folder} data-resize-height={@resize_height}>
      <input type="hidden" name={@name} value={@url} />
      <input type="file" class="hidden" {testid("image-upload-input")} />

      <%= cond do %>
        <% @uploading -> %>
          <div class="w-full h-full flex flex-col items-center justify-center p-4 font-bold border border-blue-planning-300 border-2 border-dashed rounded-lg text-xs">
            <div class="w-3 h-3 m-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
            Uploading...
          </div>
        <% @url -> %>
          <div class="w-full h-full flex items-center justify-center relative">
            <%= if assigns[:image_slot] do %>
              <%= render_slot(@image_slot) %>
            <% else %>
              <img src={@url} class="h-full w-full object-cover" />
            <% end %>
            <div class="upload-button absolute top-2 right-2 rounded-3xl bg-white shadow-lg cursor-pointer flex p-3 items-center justify-center">
              <span class="font-semibold text-blue-planning-300 hover:opacity-75">
                Choose a new image
              </span>
            </div>
          </div>
        <% true -> %>
          <div class="upload-button w-full h-full flex flex-col items-center justify-center p-4 font-bold border border-blue-planning-300 border-2 border-dashed rounded-lg cursor-pointer"> <%= if @uploading do %>
            <% else %>
              <.icon name="upload" class="w-10 h-10 mb-2 stroke-current text-blue-planning-300" />
              <p>Drag your image or <span class="text-blue-planning-300">browse</span></p>
              <p class="text-sm font-normal text-base-250"><%= @supports %></p>
            <% end %>
          </div>
      <% end %>
    </div>
    """
  end

  def image_upload_input(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "image_upload_input"} {assigns} />
    """
  end

  @impl true
  def handle_event(
        "get_signed_url",
        %{"name" => name, "type" => type, "upload_folder" => upload_folder},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    path =
      [
        [current_user.organization.slug, upload_folder],
        ["#{:os.system_time(:millisecond)}-#{name}"]
      ]
      |> Enum.concat()
      |> Path.join()

    params =
      Picsello.Galleries.Workers.PhotoStorage.params_for_upload(
        expires_in: 600,
        bucket: bucket(),
        key: path,
        field: %{
          "content-type" => type,
          "cache-control" => "public, max-age=@upload_options"
        },
        conditions: [
          [
            "content-length-range",
            0,
            String.to_integer(Application.get_env(:picsello, :photo_max_file_size))
          ]
        ]
      )

    socket
    |> assign(uploading: true)
    |> reply(params)
  end

  @impl true
  def handle_event("upload_finished", %{"url" => url}, socket) do
    socket
    |> assign(uploading: false, url: url)
    |> noreply()
  end

  defp config(), do: Application.get_env(:picsello, :profile_images)
  defp bucket, do: Keyword.get(config(), :bucket)
end
