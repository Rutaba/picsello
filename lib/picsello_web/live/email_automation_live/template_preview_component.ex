defmodule PicselloWeb.EmailAutomationLive.TemplatePreviewComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1]

  @impl true
  def update(
        assigns,
        socket
      ) do
    socket
    |> assign(assigns)
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal pt-5">
      <.close_x />

      <%= case @template_preview do %>
        <% nil -> %>
        <% :loading -> %>
          <div class="flex items-center justify-center w-full mt-10 text-xs">
            <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
            Loading...
          </div>
        <% content -> %>
          <div class="flex justify-center p-2 mt-10 rounded-lg bg-base-200">
            <iframe srcdoc={content} class="w-[30rem]" scrolling="no" phx-hook="IFrameAutoHeight" id="template-preview">
            </iframe>
          </div>
      <% end %>
    </div>
    """
  end

  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
