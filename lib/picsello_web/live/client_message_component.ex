defmodule PicselloWeb.ClientMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

  alias Ecto.Changeset
  alias Picsello.{Job, Clients}

  @default_assigns %{
    composed_event: :message_composed,
    modal_title: "Send an email",
    send_button: "Send Email",
    show_cc: false,
    show_bcc: false,
    show_client_email: true,
    show_subject: true,
    current_user: nil,
    enable_size: false,
    enable_image: false,
  }

  @impl true
  def update(%{current_user: current_user, client: %{id: id, email: email}} = assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> assign(:clients, Clients.find_all_by(user: current_user))
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:current_focus, -1)
    |> assign_new(:changeset, fn ->
      assigns
      |> Map.take([:subject, :body_text, :body_html])
      |> Map.put(:client_id, id)
      |> Picsello.ClientMessage.create_outbound_changeset()
    end)
    |> then(fn socket -> assign_presets(socket) end)
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
    <div class="modal">
      <.close_x />
      <h1 class="text-3xl"><%= @modal_title %></h1>
        <%= t = form_for :to_email, "#", phx_change: "validate_email", phx_submit: "to_email" %>
          <%= labeled_input t, :to, label: "To: ", value: "#{@client.email}", wrapper_class: classes(hidden: !@show_client_email), class: "h-12", phx_debounce: "500" %>
        <.search_clients search_results={@search_results} search_phrase={@search_phrase} current_focus={@current_focus} clients={@clients} myself={@myself}/>
      <%= if @cc do %>
        <%= c = form_for :cc_email, "#", phx_submit: "cc_email" %>
          <%= labeled_input c, :cc, label: "CC: ", wrapper_class: classes(hidden: !@show_client_email), class: "h-12", phx_debounce: "500" %>
      <% end %>
      <%= if @bcc do %>
        <%= b = form_for :bcc_email, "#", phx_submit: "bcc_email" %>
          <%= labeled_input b, :bcc, label: "BCC: ", wrapper_class: classes(hidden: !@show_client_email), class: "h-12", phx_debounce: "500" %>

      <% end %>
      <div class="flex flex-row">
        <%= if !@cc do %>
          <.icon_button class="py-1 px-4 mt-4 w-full sm:w-36 justify-center bg-white border-blue-planning-300 text-black" title="Add CC" phx-click="add-cc" phx-target={@myself} color="blue-planning-300" icon="plus">
            Add CC
          </.icon_button>
        <% end %>
        <%= if !@bcc do %>
          <.icon_button class="py-1 px-4 mt-4 ml-2 w-full sm:w-36 justify-center bg-white border-blue-planning-300 text-black" title="Add BCC" phx-click="add-bcc" phx-target={@myself} color="blue-planning-300" icon="plus">
            Add BCC
          </.icon_button>
        <% end %>
      </div>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="grid grid-flow-col gap-4 mt-4 auto-cols-fr">
          <%= if Enum.any?(@preset_options), do: labeled_select f, :preset_id, @preset_options, label: "Select email preset", class: "h-12" %>
          <%= labeled_input f, :subject, label: "Subject line", wrapper_class: classes(hidden: !@show_subject), class: "h-12", phx_debounce: "500" %>
        </div>

        <label class="block mt-4 input-label" for="editor">Message</label>
        <.quill_input f={f} html_field={:body_html} text_field={:body_text} enable_size={@enable_size} enable_image={@enable_image} current_user={@current_user} />
        <.footer>
          <button class="btn-primary px-11" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Sending...">
            <%= @send_button %>
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate_email", %{bcc: email}, %{assigns: %{clients: clients}} = socket) do
    email
    |> String.split(";", trim: true)
    |> Enum.all?(fn email -> String.match?(email, Picsello.Accounts.User.email_regex()) end)
  end

  @impl true
  def handle_event("to_email", %{to: email}, %{assigns: %{clients: clients}} = socket) do
    socket
    |> assign(:to_email, get_clients(email, clients))
  end

  @impl true
  def handle_event("cc_email", %{cc: email}, %{assigns: %{clients: clients}} = socket) do
    socket
    |> assign(:cc_email, get_clients(email, clients))
  end

  @impl true
  def handle_event("bcc_email", %{bcc: email}, %{assigns: %{clients: clients}} = socket) do
    socket
    |> assign(:bcc_email, get_clients(email, clients))
  end

  @impl true
  def handle_event("add-cc", _, socket) do
    socket
    |> assign(:show_cc, true)
    |> noreply()
  end

  @impl true
  def handle_event("add-bcc", _, socket) do
    socket
    |> assign(:show_bcc, true)
    |> noreply()
  end

  @impl true
  def handle_event("remove-cc", _, socket) do
    socket
    |> assign(:show_cc, false)
    |> noreply()
  end

  @impl true
  def handle_event("remove-bcc", _, socket) do
    socket
    |> assign(:show_bcc, false)
    |> noreply()
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
          |> Picsello.EmailPresets.resolve_variables({job}, PicselloWeb.Helpers)
      end

    socket
    |> assign_changeset(:validate, %{subject: preset.subject_template, body: preset.body_template})
    |> push_event("quill:update", %{"html" => preset.body_template})
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"client_message" => params}, socket) do
    socket
    |> assign_changeset(:validate, params)
    |> noreply()
  end

  @impl true
  def handle_event("save", %{"client_message" => params}, socket) do
    socket =
      socket
      |> assign_changeset(:validate, params)

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
          optional(:presets) => [%Picsello.EmailPresets.EmailPreset{}],
          optional(:current_user) => %Picsello.Accounts.User{},
          optional(:client) => %Picsello.Client{},
          optional(:enable_size) => boolean,
          optional(:enable_image) => boolean
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

  defp assign_presets(%{assigns: %{job: job}} = socket),
    do: assign_new(socket, :presets, fn -> Picsello.EmailPresets.for(job) end)

  defp assign_presets(socket), do: socket

  defp get_clients(email, clients),
  do:
    String.split(email, ";", trim: true)
      |> Enum.map(fn email ->
        Enum.filter(clients, &(&1.email == email))
      end)

  defp search_clients(assigns) do
    ~H"""
      <%= form_tag("#", [phx_change: :search, phx_submit: :submit, phx_target: @myself]) do %>
        <div class="flex flex-col justify-between items-center px-1.5 md:flex-row">
          <div class="relative flex md:w-full">
            <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
              <%= if Enum.any?(@search_results) do %>
                <span phx-click="clear-search" phx-target={@myself} class="cursor-pointer">
                  <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                </span>
              <% else %>
                <.icon name="search" class="w-4 ml-1 fill-current" />
              <% end %>
            </a>
            <input disabled={false} type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" phx-target={@myself} spellcheck="false" placeholder="Search clients to add to email..." />
            <%= if Enum.any?(@search_results) do %>
              <div id="search_results" class="absolute top-14 w-full" phx-window-keydown="set-focus" phx-target={@myself}>
                <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white">
                  <%= for {search_result, idx} <- Enum.with_index(@search_results) do %>
                    <div class={"flex items-center cursor-pointer p-2"} phx-click="pick" phx-target={@myself} phx-value-client_id={"#{search_result.id}"}>
                      <%= radio_button(:search_radio, :name, search_result.name, checked: idx == @current_focus, class: "mr-5 w-5 h-5 radio") %>
                      <div>
                        <p><%= search_result.name %></p>
                        <p class="text-sm"><%= search_result.email %></p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <%= if @search_phrase && @search_phrase !== "" && Enum.empty?(@search_results) do %>
                <div class="absolute top-14 w-full">
                  <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 cursor-pointer shadow py-2 px-2 bg-white">
                    <p class="font-bold">No client found with that information</p>
                    <p>You'll need to add a new client</p>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end
end
