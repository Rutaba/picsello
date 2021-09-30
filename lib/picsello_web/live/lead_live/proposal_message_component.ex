defmodule PicselloWeb.LeadLive.ProposalMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job}

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:changeset, fn ->
      assigns
      |> Map.take([:subject, :body_text, :body_html])
      |> Picsello.ProposalMessage.create_changeset()
    end)
    |> assign_new(:show_cc, fn -> false end)
    |> ok()
  end

  def render(assigns) do
    ~L"""
    <div class="modal">
      <h1 class="mt-2 text-xs font-semibold tracking-widest text-gray-400 uppercase">Compose Email</h1>

      <div class="pt-4 input-label">
        Client's email
      </div>
      <div class="relative text-input">
        <%= client_email @job %>
        <a class="absolute cursor-pointer bottom-2 right-2 text-blue-primary" phx-click="toggle-cc" phx-target="<%= @myself %>">cc</a>
      </div>

      <%= f = form_for @changeset, "#", phx_change: :validate, phx_submit: :save, phx_target: @myself %>
        <%= if @show_cc do %>
          <div class="relative">
            <%= labeled_input f, :cc_email, label: "CC Email", wrapper_class: "mt-4", phx_debounce: "500" %>
            <a class="absolute cursor-pointer top-2 right-2 text-blue-primary" phx-click="toggle-cc" phx-target="<%= @myself %>">
              <%= icon_tag(@socket, "close-modal", class: "h-3 w-3 stroke-current") %>
            </a>
            <%= if input_value(f, :cc_email) && input_value(f, :cc_email) != "" do %>
              <a id="cc-clear" class="absolute cursor-pointer bottom-2 right-2 text-blue-primary" phx-hook="ClearInput" data-input-name="cc_email">clear</a>
            <% end %>
          </div>
        <% end %>
        <%= labeled_input f, :subject, label: "Subject line", wrapper_class: "mt-4", phx_debounce: "500" %>

        <label class="block mt-4 input-label" for="editor">Message</label>
        <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore">
          <div id="toolbar" class="bg-blue-light-primary text-blue-primary">
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
        <%= live_component PicselloWeb.LiveModal.FooterComponent do %>
          <div class="text-center">
            <button class="w-full mb-4 btn-primary" type="submit" <%= unless @changeset.valid?, do: "disabled" %> phx-disable-with="Sending email...">
              Send email
            </button>

            <button class="w-full btn-secondary" type="button" phx-click="modal" phx-value-action="close">
              Close
            </button>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  def handle_event("toggle-cc", _, %{assigns: %{show_cc: show_cc}} = socket) do
    socket |> assign(:show_cc, !show_cc) |> noreply()
  end

  def handle_event("validate", %{"proposal_message" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  def handle_event("save", %{"proposal_message" => params}, socket) do
    socket = socket |> assign_changeset(:validate, params)
    %{assigns: %{changeset: changeset}} = socket

    if changeset.valid? do
      send(socket.parent_pid, {:message_composed, changeset |> Map.put(:action, nil)})
      socket |> noreply()
    else
      socket |> noreply()
    end
  end

  def open_modal(%{assigns: assigns} = socket, opts \\ []),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns:
            opts
            |> Enum.into(assigns)
            |> Map.take([:current_user, :job, :subject, :body_html, :body_text])
        }
      )

  def client_email(%Job{client: %{email: email}}), do: email

  defp assign_changeset(
         socket,
         action,
         params
       ) do
    changeset = params |> Picsello.ProposalMessage.create_changeset() |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end
end
