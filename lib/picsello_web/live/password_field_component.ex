defmodule PicselloWeb.PasswordFieldComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    assigns = assigns |> Enum.into(%{class: nil})

    ~H"""
    <div class='flex flex-col mt-4'>
      <%= label_for @f, @name, label: @label %>
      <div class='relative'>
        <% password_input_type = if @hide_password, do: :password_input, else: :text_input %>
        <%= input @f, @name, type: password_input_type, placeholder: @placeholder, value: input_value(@f, @name), phx_debounce: "500", wrapper_class: "mt-4", class: "w-full pr-16 #{@class}"%>

        <a href='#' phx-click="toggle-password" phx-target={ @myself } class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 right-2">
          <%= if @hide_password do %>
            <div class="pb-0.5">show</div>
            <.icon name="eye" class="w-4 ml-1 fill-current" />
          <% else %>
            <div class="pb-0.5">hide</div>
            <.icon name="closed-eye" class="w-4 ml-1 fill-current" />
          <% end %>
        </a>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket), do: socket |> assign(hide_password: true) |> ok()

  @impl true
  def update(assigns, socket),
    do: socket |> assign(assigns |> Enum.into(%{label: "Password", name: :password})) |> ok()

  @impl true
  def handle_event("toggle-password", %{}, %{assigns: %{hide_password: hide_password}} = socket),
    do: socket |> assign(hide_password: !hide_password) |> noreply()
end
