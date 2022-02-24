defmodule PicselloWeb.ClientMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job}

  @default_assigns %{
    composed_event: :message_composed,
    modal_title: "Send an email",
    send_button: "Send Email",
    show_cc: false,
    show_client_email: true,
    show_subject: true
  }

  defmodule PresetHelper do
    @moduledoc """
      functions only available in the PicselloWeb module needed to resolve mustache variables.
      here to avoid calling PicselloWeb from Picsello.
    """

    require PicselloWeb.Gettext

    def ngettext(singular, plural, count) do
      Gettext.dngettext(PicselloWeb.Gettext, "picsello", singular, plural, count, %{})
    end

    defdelegate strftime(zone, date, format), to: PicselloWeb.LiveHelpers
    defdelegate shoot_location(shoot), to: PicselloWeb.LiveHelpers

    def profile_pricing_job_type_url(slug, type),
      do:
        PicselloWeb.Endpoint
        |> PicselloWeb.Router.Helpers.profile_url(
          :index,
          slug
        )
        |> URI.parse()
        |> Map.put(:fragment, type)
        |> URI.to_string()
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> assign_new(:changeset, fn ->
      assigns
      |> Map.take([:subject, :body_text, :body_html])
      |> Picsello.ClientMessage.create_outbound_changeset()
    end)
    |> then(fn %{assigns: %{job: job}} = socket ->
      assign_new(socket, :presets, fn -> Picsello.EmailPreset.for_job(job) end)
    end)
    |> then(fn %{assigns: %{presets: presets}} = socket ->
      assign(socket, preset_options: Enum.map(presets, &{&1.name, &1.id}))
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 class="text-3xl font-bold"><%= @modal_title %></h1>

      <%= if @show_client_email do %>
        <div class="pt-5 input-label">
          Client's email
        </div>
        <div class="relative text-input text-base-250">
          <%= client_email @job %>
        </div>
      <% end %>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="grid grid-flow-col auto-cols-fr gap-4 mt-4">
          <%= if Enum.any?(@preset_options), do: labeled_select f, :preset_id, @preset_options, label: "Select email preset", class: "h-12" %>
          <%= labeled_input f, :subject, label: "Subject line", wrapper_class: classes(hidden: !@show_subject), class: "h-12", phx_debounce: "500" %>
        </div>

        <label class="block mt-4 input-label" for="editor">Message</label>
        <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore" data-text-field-name={input_name(f, :body_text)} data-html-field-name={input_name(f, :body_html)}>
          <div id="toolbar">
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
            <%= @send_button %>
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
  def handle_event(
        "validate",
        %{
          "client_message" => %{"preset_id" => preset_id},
          "_target" => ["client_message", "preset_id"]
        },
        %{assigns: %{presets: presets, job: job}} = socket
      ) do
    preset_id = String.to_integer(preset_id)

    preset =
      presets
      |> Enum.find(&(Map.get(&1, :id) == preset_id))
      |> Picsello.EmailPreset.resolve_variables(job, PresetHelper)

    socket
    |> assign_changeset(:validate, %{subject: preset.subject_template, body: preset.body_template})
    |> push_event("quill:update", %{"text" => preset.body_template})
    |> noreply()
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
          optional(:body_html) => String.t(),
          optional(:body_text) => any,
          optional(:composed_event) => any,
          optional(:modal_title) => String.t(),
          optional(:send_button) => String.t(),
          optional(:show_client_email) => boolean,
          optional(:show_subject) => boolean,
          optional(:subject) => String.t(),
          optional(:presets) => [%Picsello.EmailPreset{}]
        }) :: %Phoenix.LiveView.Socket{}
  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:job]))
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
