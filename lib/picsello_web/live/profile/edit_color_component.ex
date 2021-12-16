defmodule PicselloWeb.Live.Profile.EditColorComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-sm ">
      <h1 class="text-3xl font-bold">Edit color</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <ul class="mt-4 grid grid-cols-4 gap-5 sm:gap-3 max-w-sm">
            <%= for(color <- colors()) do %>
              <li class="aspect-h-1 aspect-w-1">
                <label>
                  <%= radio_button p, :color, color, class: "hidden" %>
                  <div class={classes(
                    "flex cursor-pointer items-center hover:border-base-300 justify-center w-full h-full border rounded", %{
                    "border-base-300" => input_value(p, :color) == color,
                    "hover:border-opacity-40" => input_value(p, :color) != color
                  })}>
                    <div class="w-4/5 rounded h-4/5" style={"background-color: #{color}"}></div>
                  </div>
                </label>
              </li>
            <% end %>
          </ul>
        <% end %>

        <PicselloWeb.LiveModal.footer />
      </.form>
    </div>
    """
  end

  @impl true
  defdelegate update(assigns, socket), to: PicselloWeb.Live.Profile.Shared

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.Live.Profile.Shared

  defdelegate colors(), to: Picsello.Profiles

  def open(socket), do: PicselloWeb.Live.Profile.Shared.open(socket, __MODULE__)
end
