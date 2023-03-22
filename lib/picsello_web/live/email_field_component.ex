defmodule PicselloWeb.EmailFieldComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    class = Map.get(assigns, :class, nil)

    ~H"""
    <div class='flex flex-col mt-4'>
      <%= label_for @f, @name, label: @label %>
      <div class='relative'>
        <%= input @f, @name, placeholder: @placeholder, value: input_value(@f, @name), phx_debounce: "500", wrapper_class: "mt-4", class: "w-full pr-16 #{class}"%>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket), do: socket |> ok()

  @impl true
  def update(assigns, socket),
    do: socket |> assign(assigns |> Enum.into(%{label: "Email", name: :email})) |> ok()
end
