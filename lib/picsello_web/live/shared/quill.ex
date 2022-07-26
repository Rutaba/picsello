defmodule PicselloWeb.Shared.Quill do
  @moduledoc """
    Helper functions to use the Quill component
  """
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        id: "editor",
        html_field: nil,
        text_field: nil,
        placeholder: nil,
        class: nil,
        editor_class: "min-h-[8rem]",
        enable_size: false,
        enable_image: false,
        track_quill_source: false,
        current_user: nil
      })

    ~H"""
    <div id={"#{@id}-wrapper"} class={@class} phx-hook="Quill" phx-update="ignore" class="mt-2"
      data-placeholder={@placeholder}
      data-html-field-name={input_name(@f, @html_field)}
      data-text-field-name={input_name(@f, @text_field)}
      data-enable-size={@enable_size}
      data-enable-image={@enable_image}
      data-target={@myself}>
      <%= if @enable_image do %>
        <input type="file" class="hidden" {testid("quill-image-input")} />
      <% end %>
      <%= if @track_quill_source do %>
        <%= hidden_input @f, :quill_source %>
      <% end %>
      <div class={"#{@editor_class} editor"}></div>
      <%= if @html_field, do: hidden_input @f, @html_field, phx_debounce: "500" %>
      <%= if @text_field, do: hidden_input @f, @text_field, phx_debounce: "500" %>
    </div>
    """
  end

  def quill_input(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "quill_input"} {assigns} />
    """
  end

  @impl true
  def handle_event(
        "get_signed_url",
        %{"name" => name, "type" => type},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    path =
      [[current_user.organization.slug, "email"], ["#{:os.system_time(:millisecond)}-#{name}"]]
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
    |> reply(params)
  end

  defp config(), do: Application.get_env(:picsello, :profile_images)
  defp bucket, do: Keyword.get(config(), :bucket)
end
