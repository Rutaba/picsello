defmodule PicselloWeb.ClientMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

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
    |> assign(:recipients, %{to: [email]})
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:current_focus, -1)
    |> assign_new(:bcc_email_error, fn -> nil end)
    |> assign_new(:cc_email_error, fn -> nil end)
    |> assign_new(:to_email_error, fn -> nil end)
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
      <h1 class="text-3xl mb-4"><%= @modal_title %></h1>
        <div class="flex flex-col">
          <label for="to_email" class="text-sm font-semibold mb-2">To: <span class="font-light text-sm ml-0.5 italic">(semicolon separated to add more emails)</span></label>
          <div class="flex flex-col md:flex-row">
            <input type="text" class="w-2/3 text-input" id="to_email" value={"#{Enum.join(Map.get(@recipients, :to), "; ")}"} phx-keyup="validate_to_email" phx-target={@myself} phx-debounce="1000" spellcheck="false"/>
            <.search_existing_clients search_results={@search_results} search_phrase={@search_phrase} current_focus={@current_focus} clients={@clients} myself={@myself}/>
          </div>
          <span class={classes("text-red-sales-300 text-sm", %{"hidden" => !@to_email_error})}><%= @to_email_error %></span>
          </div>

        <%= if @show_cc do %>
          <div clas="flex flex-row">
            <div class="flex flex-col md:flex-row mt-4">
              <label for="cc_email" class="text-sm font-semibold mb-2">CC: <span class="font-light text-sm ml-0.5 italic">(semicolon separated to add more emails)</span></label>
              <.icon_button class="bg-white border-red-sales-300 mr-0" title="remove" phx-click="remove-cc" phx-target={@myself} color="red-sales-300" icon="trash"/>
            </div>
            <input type="text" class="w-2/3 text-input" id="cc_email" value={(if Map.has_key?(@recipients, :cc), do: "#{Enum.join(Map.get(@recipients, :cc, []), "; ")}", else: "")} phx-keyup="validate_cc_email" phx-target={@myself} phx-debounce="1000" spellcheck="false"/>
            <span class={classes("text-red-sales-300 text-sm", %{"hidden" => !@cc_email_error})}><%= @cc_email_error %></span>
          </div>
        <% end %>
        <%= if @show_bcc do %>
          <div clas="flex flex-row">
            <div class="flex flex-col md:flex-row mt-4">
              <label for="bcc_email" class="text-sm font-semibold mb-2">BCC: <span class="font-light text-sm ml-0.5 italic">(semicolon separated to add more emails)</span></label>
              <.icon_button class="bg-white border-red-sales-300 mr-0" title="remove" phx-click="remove-bcc" phx-target={@myself} color="red-sales-300" icon="trash"/>
            </div>
            <input type="text" class="w-2/3 text-input" id="bcc_email" value={(if Map.has_key?(@recipients, :bcc), do: "#{Enum.join(Map.get(@recipients, :bcc, []), "; ")}", else: "")} phx-keyup="validate_bcc_email" phx-target={@myself} phx-debounce="1000" spellcheck="false"/>
            <span class={classes("text-red-sales-300 text-sm", %{"hidden" => !@bcc_email_error})}><%= @bcc_email_error %></span>
          </div>
        <% end %>
        <div class="flex flex-row">
        <%= if !@show_cc do %>
          <.icon_button class="py-1 px-4 mt-4 w-full sm:w-36 justify-center bg-white border-blue-planning-300 text-black" title="Add CC" phx-click="show-cc" phx-target={@myself} color="blue-planning-300" icon="plus">
            Add CC
          </.icon_button>
        <% end %>
        <%= if !@show_bcc do %>
          <.icon_button class="py-1 px-4 mt-4 ml-2 w-full sm:w-36 justify-center bg-white border-blue-planning-300 text-black" title="Add BCC" phx-click="show-bcc" phx-target={@myself} color="blue-planning-300" icon="plus">
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
          <button class="btn-primary px-11" title="save" type="submit" disabled={!@changeset.valid? || @to_email_error || @cc_email_error || @bcc_email_error} phx-disable-with="Sending...">
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
  def handle_event("validate_bcc_email", %{"value" => email}, %{assigns: %{recipients: recipients}} = socket) do
    IO.inspect("inside validate bcc")
    validate_email(email, :bcc, socket)
  end

  @impl true
  def handle_event("validate_cc_email", %{"cc" => email}, %{assigns: %{recipients: recipients}} = socket) do
    IO.inspect("inside validate cc")
    validate_email(email, :cc, socket)
  end

  @impl true
  def handle_event("validate_to_email", %{"value" => email}, socket) do
    IO.inspect(email, label: "inside validate to")
    validate_email(email, :to, socket)
  end

  @impl true
  def handle_event("add-to", %{"client-email" => email}, %{assigns: %{recipients: recipients}} = socket) do
    prepend_email(email, :to, socket)
    |> noreply()
  end

  @impl true
  def handle_event("add-cc", %{"client-email" => email}, %{assigns: %{recipients: recipients}} = socket) do
    prepend_email(email, :cc, socket)
    |> assign(:show_cc, true)
    |> noreply()
  end

  @impl true
  def handle_event("add-bcc", %{"client-email" => email}, %{assigns: %{recipients: recipients}} = socket) do
    prepend_email(email, :bcc, socket)
    |> assign(:show_bcc, true)
    |> noreply()
  end

  @impl true
  def handle_event("show-cc", _, socket) do
    socket
    |> assign(:show_cc, true)
    |> noreply()
  end

  @impl true
  def handle_event("show-bcc", _, socket) do
    socket
    |> assign(:show_bcc, true)
    |> noreply()
  end

  @impl true
  def handle_event("remove-cc", _, %{assigns: %{recipients: recipients}} = socket) do
    socket
    |> assign(:show_cc, false)
    |> assign(:recipients, Map.put(recipients, :cc, []))
    |> assign(:cc_email_error, nil)
    |> noreply()
  end

  @impl true
  def handle_event("remove-bcc", _, %{assigns: %{recipients: recipients}} = socket) do
    socket
    |> assign(:show_bcc, false)
    |> assign(:recipients, Map.put(recipients, :bcc, []))
    |> assign(:bcc_email_error, nil)
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
    IO.inspect("Inside save handle_event")
    socket =
      socket
      |> assign_changeset(:validate, params)

    %{assigns: %{changeset: changeset, composed_event: composed_event, recipients: recipients}} = socket
    IO.inspect(socket.assigns.recipients)

    if changeset.valid?,
    do: send(socket.parent_pid, {composed_event, changeset |> Map.put(:action, nil), recipients})

    socket |> noreply()
  end

  defdelegate handle_event(event, params, socket), to: PicselloWeb.JobLive.Shared

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

  defp get_clients(email_list, clients, type),
  do:
    email_list
    |> Enum.reduce(%{}, fn email, acc ->
      acc
      |> Map.put(:client, Enum.filter(clients, &(&1.email == String.trim(email))))
      |> Map.put(:recipient_type, type)
    end)

  defp prepend_email(email, type, %{assigns: %{recipients: recipients}} = socket) do
    email_list = recipients |> Map.get(type, []) |> List.insert_at(-1, String.downcase(email)) |> IO.inspect

    socket
    |> assign(:recipients, Map.put(recipients, :to, email_list))
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
  end

  defp validate_email(email, type, %{assigns: %{recipients: recipients}} = socket) do
    email_list =
      email
      |> String.downcase()
      |> String.split(";", trim: true)

    valid_emails? =
      email_list
      |> Enum.all?(fn email ->
        email
        |> String.trim()
        |> String.match?(Picsello.Accounts.User.email_regex())
      end)

    if valid_emails? do
      socket
      |> assign(:to_email_error, nil)
    else
      socket
      |> assign(:to_email_error, "please enter valid emails")
    end
    |> assign(:recipients, Map.put(recipients, type, email_list) |> IO.inspect)
    |> noreply()
  end

  defp search_existing_clients(assigns) do
    ~H"""
      <%= form_tag("#", [phx_change: :search, phx_target: @myself]) do %>
        <div class="flex flex-col w-full justify-between items-center px-1.5 md:flex-row">
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
            <input type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" spellcheck="false" phx-target={@myself} placeholder="Search clients to add to email..." />
            <%= if Enum.any?(@search_results) do %>
              <div id="search_results" class="absolute top-14 w-full" phx-window-keydown="set-focus" phx-target={@myself}>
                <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white">
                  <%= for {search_result, idx} <- Enum.with_index(@search_results) do %>
                    <div class={"flex items-center cursor-pointer p-2"}>
                      <div>
                        <p class="font-bold"><%= search_result.name %></p>
                        <p class="text-sm"><%= search_result.email %></p>
                        <div class="flex flex-row mt-2">
                        <.add_icon_button title="Add to", click_event="add-to", myself={@myself}, search_result={search_result}/>
                        <.add_icon_button title="Add CC", click_event="add-cc",  myself={@myself}, search_result={search_result}/>
                        <.add_icon_button title="Add BCC", click_event="add-bcc", myself={@myself}, search_result={search_result}/>

                        </div>
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

  defp add_icon_button(assigns) do
    ~H"""
      <.icon_button class="py-1 px-4 w-auto sm:w-24 justify-center bg-white border-blue-planning-300 text-black" title={@title} phx-click={@click_event} phx-target={@myself} phx-value-client_email={"#{@search_result.email}"} color="blue-planning-300" icon="plus">
        <%= @title %>
      </.icon_button>
    """
  end
end
