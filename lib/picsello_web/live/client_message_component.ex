defmodule PicselloWeb.ClientMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(Enum.into(assigns, %{composed_event: :message_composed, show_cc: false}))
    |> assign_new(:changeset, fn ->
      assigns
      |> Map.take([:subject, :body_text, :body_html])
      |> Picsello.ClientMessage.create_outbound_changeset()
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 class="text-3xl font-bold">Send an email</h1>

      <div class="pt-5 input-label">
        Client's email
      </div>
      <div class="relative text-input">
        <%= client_email @job %>
        <a class="absolute cursor-pointer bottom-2 right-2 text-blue-planning-300" phx-click="toggle-cc" phx-target={@myself}>cc</a>
      </div>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <%= if @show_cc do %>
          <div class="relative">
            <%= labeled_input f, :cc_email, label: "CC Email", wrapper_class: "mt-4", phx_debounce: "500" %>
            <a class="absolute cursor-pointer top-2 right-2 text-blue-planning-300" phx-click="toggle-cc" phx-target={@myself}>
              <.icon name="close-x" class="w-3 h-3 stroke-current"/>
            </a>
            <%= if input_value(f, :cc_email) && input_value(f, :cc_email) != "" do %>
              <a id="cc-clear" class="absolute cursor-pointer bottom-2 right-2 text-blue-planning-300" phx-hook="ClearInput" data-input-name="cc_email">clear</a>
            <% end %>
          </div>
        <% end %>
        <%= labeled_input f, :subject, label: "Subject line", wrapper_class: "mt-4", phx_debounce: "500" %>

        <label class="block mt-4 input-label" for="editor">Message</label>
        <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore">
          <div id="toolbar" class="bg-blue-planning-100 text-blue-planning-300">
            <button class="ql-bold"></button>
            <button class="ql-italic"></button>
            <button class="ql-underline"></button>
            <button class="ql-list" value="bullet"></button>
            <button class="ql-list" value="ordered"></button>
            <button class="ql-link"></button>
          </div>
          <div id="editor" style="min-height: 4rem;"> </div>
          <%= hidden_input f, :body_text, phx_debounce: "500" %>
          <%= hidden_input f, :body_html, phx_debounce: "500" %>
        </div>
        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Sending...">
            Send Email
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("toggle-cc", _, %{assigns: %{show_cc: show_cc}} = socket) do
    socket |> assign(:show_cc, !show_cc) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"client_message" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"client_message" => params}, socket) do
    socket = socket |> assign_changeset(:validate, params)
    %{assigns: %{changeset: changeset, composed_event: composed_event}} = socket

    if changeset.valid? do
      send(socket.parent_pid, {composed_event, changeset |> Map.put(:action, nil)})
      socket |> noreply()
    else
      socket |> noreply()
    end
  end

  @spec open(%Phoenix.LiveView.Socket{}, %{
          optional(:subject) => binary,
          optional(:body_text) => any,
          optional(:body_html) => binary,
          optional(:composed_event) => any
        }) :: %Phoenix.LiveView.Socket{}
  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:current_user, :job]))
        }
      )

  def client_email(%Job{client: %{email: email}}), do: email

  defp assign_changeset(
         socket,
         action,
         params
       ) do
    changeset =
      params |> Picsello.ClientMessage.create_outbound_changeset() |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end
end
