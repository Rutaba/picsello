defmodule PicselloWeb.JobLive.GalleryTypeComponent do
  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:from_job?, fn -> nil end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:main_class, fn -> "p-8" end)
      |> assign_new(:button_title, fn -> "Get Started" end)
      |> assign_new(:hide_close_button, fn -> false end)

    ~H"""
    <div class={"#{@main_class} items-center mx-auto bg-white relative"}>
      <%= unless @hide_close_button do %>
        <.close_x />
      <% end %>

      <h1 class={"#{!@from_job? && 'hidden'} font-bold text-3xl mb-8"}>Set Up Your Gallery</h1>
      <.card color="base-200" icon="photos-2" title="Standard" button_class="btn-secondary" type="standard" {assigns}>
        <p>Use this option if you already have your photos retouched, </p>
        <p> and your photos are ready to hand off to your client.</p>
      </.card>
      <.card color="blue-planning-300" icon="proofing" title="Proofing" button_class="btn-primary" type="proofing" {assigns}>
        <p>Use this option if you have proofs, but your client still needs</p>
        <p> to select which photos they’d like retouched.</p>
      </.card>
    </div>
    """
  end

  def card(assigns) do
    assigns = Enum.into(assigns, %{target: assigns.myself})

    ~H"""
      <div class={"border hover:border-#{@color} h-full my-3 rounded-lg bg-#{@color} overflow-hidden"}>
        <div class="h-full p-8 ml-3 bg-white flex items-center">
            <.icon name={@icon} class="w-11 h-11 inline-block mr-2 rounded-sm fill-current text-blue-planning-300" />
            <div class="flex flex-col">
              <h1 class="text-lg font-bold">
                <%= @title %> Gallery
              </h1>
              <%= render_block(@inner_block) %>
            </div>
            <button class={"#{@button_class} px-9 ml-28"} phx-value-type={@type} phx-click="gallery_type" phx-target={@target} phx-disable-with="Next">
              <%= @button_title %>
            </button>
        </div>
      </div>
    """
  end

  @impl true
  def handle_event("gallery_type", %{"type" => type}, socket)
      when type in ~w(proofing standard) do
    send(self(), {:gallery_type, type})

    socket |> noreply()
  end
end
