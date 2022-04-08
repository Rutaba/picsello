defmodule PicselloWeb.GalleryLive.Shared.GalleryMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job}
  import PicselloWeb.PackageLive.Shared, only: [quill_input: 1, custom_quill_input: 1]

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
    |> then(fn
      %{assigns: %{presets: [_ | _] = presets}} = socket ->
        assign(socket, preset_options: [{"none", ""} | Enum.map(presets, &{&1.name, &1.id})])

      socket ->
        assign(socket, preset_options: [])
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do

    ~H"""
    <div class="modal" style="border-radius: 0.375rem;">
    <div class="flex justify-between">
        <h1 class="mb-4 text-3xl font-bold"><%= @modal_title %></h1>
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>

      <%= if @show_client_email do %>
        <div class="pt-5 font-bold input-label">
          Client's email
        </div>
        <div class="relative font-sans text-input text-base-250" style="border-radius: 0.375rem;">
          <%= client_email @job %>
        </div>
      <% end %>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="grid grid-flow-col gap-4 mt-4 font-bold auto-cols-fr">
          <%= labeled_input f, :subject, label: "Subject line", wrapper_class: classes(hidden: !@show_subject), class: "font-sans h-12", phx_debounce: "500",  style: "border-radius: 0.375rem;" %>
        </div>

        <label class="block mt-4 font-bold input-label" for="editor">Message</label>
        <.custom_quill_input f={f} style={"min-height: 4rem; font-family: 'Be Vietnam'; font-style: normal; font-weight: 500; font-size: 15.4282px;
        line-height: 23px; border-bottom-left-radius: 0.375rem; border-bottom-right-radius: 0.375rem;"} html_field={:body_html} text_field={:body_text}/>

     <PicselloWeb.LiveModal.custom_footer>
          <button class="btn-settings ml-4 w-40 px-11 py-3.5 cursor-pointer" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Sending...">
            <%= @send_button %>
          </button>
          <button class="w-28 btn-settings-secondary" title="close" type="button" phx-click="modal" phx-value-action="close">
            Close
          </button>
        </PicselloWeb.LiveModal.custom_footer>
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
    preset =
      case Integer.parse(preset_id) do
        :error ->
          %{subject_template: "", body_template: ""}

        {preset_id, _} ->
          presets
          |> Enum.find(&(Map.get(&1, :id) == preset_id))
          |> Picsello.EmailPreset.resolve_variables(job, PresetHelper)
      end

    socket
    |> assign_changeset(:validate, %{subject: preset.subject_template, body: preset.body_template})
    |> push_event("quill:update", %{"html" => preset.body_template})
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
