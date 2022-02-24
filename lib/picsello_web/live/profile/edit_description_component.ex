defmodule PicselloWeb.Live.Profile.EditDescriptionComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-md ">
      <h1 class="text-3xl font-bold">Edit Description</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore" class="mt-4" data-placeholder="Start typing…" data-html-field-name={input_name(p, @field_name)}>
            <div id="toolbar" class="bg-blue-planning-100 text-blue-planning-300">
              <button class="ql-bold"></button>
              <button class="ql-italic"></button>
              <button class="ql-underline"></button>
              <button class="ql-list" value="bullet"></button>
              <button class="ql-list" value="ordered"></button>
              <button class="ql-link"></button>
            </div>
            <div id="editor" style="min-height: 4rem;"> </div>
            <%= hidden_input p, @field_name, phx_debounce: "500" %>
          </div>
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

  def open(socket, field_name) do
    socket
    |> assign(:field_name, String.to_atom(field_name))
    |> PicselloWeb.Live.Profile.Shared.open(__MODULE__)
  end
end
