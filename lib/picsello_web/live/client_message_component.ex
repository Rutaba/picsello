defmodule PicselloWeb.ClientMessageComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

  alias Picsello.{Repo, Job, Clients}

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
    enable_image: false
  }

  @impl true
  def update(%{current_user: current_user, client: %{email: email} = client} = assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> assign(:client, client)
    |> assign(:clients, Clients.find_all_by(user: current_user))
    |> assign(:recipients, %{"to" => [email]})
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:current_focus, -1)
    |> assign_new(:bcc_email_error, fn -> nil end)
    |> assign_new(:cc_email_error, fn -> nil end)
    |> assign_new(:to_email_error, fn -> nil end)
    |> then(fn %{assigns: assigns} = socket ->
      socket
      |> assign_changeset(:validate, Map.take(assigns, [:subject, :body_text, :body_html]))
    end)
    |> then(fn socket ->
      socket
      |> assign_presets()
      |> re_assign_clients()
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
    <div class="modal">
      <.close_x />
      <h1 class="text-3xl mb-4"><%= @modal_title %></h1>
        <div class="flex flex-col">
          <label for="to_email" class="text-sm font-semibold mb-2">To: <span class="font-light text-sm ml-0.5 italic">(semicolon separated to add more emails)</span></label>
          <div class="flex flex-col md:flex-row">
            <input type="text" class="w-full md:w-2/3 text-input" id="to_email" value={"#{Enum.join(Map.get(@recipients, "to"), "; ")}"} phx-keyup="validate_to_email" phx-target={@myself} phx-debounce="1000" spellcheck="false"/>
            <.search_existing_clients search_results={@search_results} search_phrase={@search_phrase} current_focus={@current_focus} clients={@clients} myself={@myself}/>
          </div>
          <span class={classes("text-red-sales-300 text-sm", %{"hidden" => !@to_email_error})}><%= @to_email_error %></span>
        </div>

        <%= if @show_cc do %>
          <.show_optional_input email_type="cc" error={@cc_email_error} myself={@myself} recipients={@recipients} />
        <% end %>
        <%= if @show_bcc do %>
          <.show_optional_input email_type="bcc" error={@bcc_email_error} myself={@myself} recipients={@recipients} />
        <% end %>
        <div class="flex flex-row mt-4">
        <%= if !@show_cc do %>
          <.icon_button class="w-full md:w-28 justify-center bg-white border-blue-planning-300 text-black" phx-click="show-cc" phx-target={@myself} color="blue-planning-300" icon="plus">
            Add Cc
          </.icon_button>
        <% end %>
        <%= if !@show_bcc do %>
          <.icon_button class="ml-2 w-full md:w-28 justify-center bg-white border-blue-planning-300 text-black" phx-click="show-bcc" phx-target={@myself} color="blue-planning-300" icon="plus">
            Add Bcc
          </.icon_button>
        <% end %>
      </div>
      <hr class="my-4"/>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="grid grid-flow-row md:grid-flow-col md:auto-cols-fr md:gap-4 mt-2">
          <%= if Enum.any?(@preset_options), do: labeled_select f, :preset_id, @preset_options, label: "Select email preset", class: "h-12" %>
          <%= labeled_input f, :subject, label: "Subject line", wrapper_class: classes(hidden: !@show_subject), class: "h-12", phx_debounce: "500" %>
        </div>

        <label class="block mt-4 input-label" for="editor">Message</label>
        <.quill_input f={f} html_field={:body_html} text_field={:body_text} enable_size={@enable_size} enable_image={@enable_image} current_user={@current_user} />
        <.footer>
          <button class="btn-primary px-11" title={@send_button} type="submit" disabled={!@changeset.valid? || @to_email_error || @cc_email_error || @bcc_email_error} phx-disable-with="Sending...">
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
  def handle_event("validate_bcc_email", %{"value" => email}, socket) do
    validate_email(email, "bcc", socket)
  end

  @impl true
  def handle_event("validate_cc_email", %{"value" => email}, socket) do
    validate_email(email, "cc", socket)
  end

  @impl true
  def handle_event("validate_to_email", %{"value" => email}, socket) do
    validate_email(email, "to", socket)
  end

  @impl true
  def handle_event("add-to", %{"client-email" => email}, socket) do
    prepend_email(email, "to", socket)
    |> noreply()
  end

  @impl true
  def handle_event("add-cc", %{"client-email" => email}, socket) do
    prepend_email(email, "cc", socket)
    |> assign(:show_cc, true)
    |> noreply()
  end

  @impl true
  def handle_event("add-bcc", %{"client-email" => email}, socket) do
    prepend_email(email, "bcc", socket)
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
    |> assign(:recipients, Map.put(recipients, "cc", []))
    |> assign(:cc_email_error, nil)
    |> noreply()
  end

  @impl true
  def handle_event("remove-bcc", _, %{assigns: %{recipients: recipients}} = socket) do
    socket
    |> assign(:show_bcc, false)
    |> assign(:recipients, Map.put(recipients, "bcc", []))
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
    |> assign_changeset(:validate, %{
      subject: preset.subject_template,
      body_html: preset.body_template
    })
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
  def handle_event("save", %{"client_message" => _params}, socket) do
    %{assigns: %{changeset: changeset, composed_event: composed_event, recipients: recipients}} =
      socket

    if changeset.valid?,
      do:
        send(socket.parent_pid, {composed_event, changeset |> Map.put(:action, nil), recipients})

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
    params =
      params |> Map.replace(:body_html, remove_client_name(socket, Map.get(params, :body_html)))

    changeset =
      params |> Picsello.ClientMessage.create_outbound_changeset() |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp assign_presets(%{assigns: %{job: job}} = socket),
    do: assign_new(socket, :presets, fn -> Picsello.EmailPresets.for(job) end)

  defp assign_presets(socket), do: socket

  defp re_assign_clients(%{assigns: %{recipients: recipients, clients: clients}} = socket) do
    email_list = recipients |> Map.values() |> List.flatten()

    socket
    |> assign(:clients, Enum.filter(clients, fn c -> c.email not in email_list end))
  end

  defp prepend_email(email, type, %{assigns: %{recipients: recipients}} = socket) do
    email_list =
      recipients
      |> Map.get(type, [])
      |> List.insert_at(-1, String.downcase(email))

    socket
    |> assign(:recipients, Map.put(recipients, type, email_list))
    |> then(fn socket -> socket |> re_assign_clients() end)
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
  end

  defp validate_email(
         email,
         type,
         %{assigns: %{recipients: recipients, current_user: user}} = socket
       ) do
    email_list =
      email
      |> String.downcase()
      |> String.split(";", trim: true)
      |> Enum.map(fn email ->
        String.trim(email)
      end)

    valid_emails? =
      email_list
      |> Enum.all?(fn email ->
        Repo.exists?(Clients.get_client_query(user, email: email))
      end)

    if valid_emails? do
      socket
      |> assign(:"#{type}_email_error", nil)
    else
      socket
      |> assign(
        :"#{type}_email_error",
        "please enter valid client emails that already exist in the system"
      )
    end
    |> assign(:recipients, Map.put(recipients, type, email_list))
    |> then(fn socket -> re_assign_clients(socket) end)
    |> noreply()
  end

  defp remove_client_name(
         %{assigns: %{client: client}} = _socket,
         body_html
       ) do
    if blank?(body_html) do
      body_html
    else
      greeting = body_html |> String.split() |> hd() |> String.replace("<p>", "")

      String.replace(
        body_html,
        "#{greeting} #{client.name |> String.split() |> hd()}",
        "#{greeting}"
      )
    end
  end

  defp email_buttons() do
    [
      %{title: "Add to", action_event: "add-to"},
      %{title: "Add Cc", action_event: "add-cc"},
      %{title: "Add Bcc", action_event: "add-bcc"}
    ]
  end

  defp search_existing_clients(assigns) do
    ~H"""
      <div class="w-full md:w-1/3 md:ml-6">
        <%= form_tag("#", [phx_change: :search, phx_target: @myself]) do %>
          <div class="relative flex flex-col w-full md:flex-row">
            <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
              <%= if Enum.any?(@search_results) || @search_phrase do %>
                <span phx-click="clear-search" phx-target={@myself} class="cursor-pointer">
                  <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                </span>
              <% else %>
                <.icon name="search" class="w-4 ml-1 fill-current" />
              <% end %>
            </a>
            <input type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" spellcheck="false" phx-target={@myself} placeholder="Search clients to add to email..." />
            <%= if Enum.any?(@search_results) && @search_phrase do %>
                <div id="search_results" class="absolute top-14 w-full z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white">
                  <%= for search_result <- Enum.take(@search_results, 5) do %>
                    <div {testid("search-row")} class={"flex items-center cursor-pointer p-3"}>
                      <div class="w-full">
                        <p class="font-bold"><%= search_result.name %></p>
                        <p class="text-sm"><%= search_result.email %></p>
                        <div class="flex justify-between mt-2">
                        <%= for %{title: title, action_event: event} <- email_buttons() do %>
                          <.add_icon_button title={title} click_event={event} myself={@myself} search_result={search_result}/>
                        <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
              </div>
            <% else %>
              <%= if @search_phrase && @search_phrase && Enum.empty?(@search_results) do %>
                <div class="absolute top-14 w-full">
                  <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 cursor-pointer shadow py-2 px-2 bg-white">
                    <p class="font-bold">No clients found with that info</p>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    """
  end

  defp show_optional_input(assigns) do
    ~H"""
      <div clas="flex flex-col">
        <div class="flex flex-row mt-4 md:items-center mb-2">
          <label for={"#{@email_type}_email"} class="text-sm font-semibold"><%= String.capitalize(@email_type) %>: <span class="font-light text-sm ml-0.5 italic">(semicolon separated to add more emails)</span></label>
          <.icon_button class="ml-10 w-8 bg-white border-red-sales-300" title={"remove-#{@email_type}"} phx-click={"remove-#{@email_type}"} phx-target={@myself} color="red-sales-300" icon="trash"/>
        </div>
        <div class="flex flex-col">
          <input type="text" class="w-full md:w-2/3 text-input" id={"#{@email_type}_email"} value={(if Map.has_key?(@recipients, @email_type), do: "#{Enum.join(Map.get(@recipients, @email_type, []), "; ")}", else: "")} phx-keyup={"validate_#{@email_type}_email"} phx-target={@myself} phx-debounce="1000" spellcheck="false" placeholder="enter email(s)…"/>
          <span {testid("#{@email_type}-error")} class={classes("text-red-sales-300 text-sm", %{"hidden" => !@error})}><%= @error %></span>
        </div>
      </div>
    """
  end

  defp add_icon_button(assigns) do
    ~H"""
      <.icon_button_ class="w-auto sm:w-24 justify-center bg-gray-100 text-black text-sm" title={@title} phx-click={@click_event} phx-target={@myself} phx-value-client_email={"#{@search_result.email}"} color="blue-planning-300" icon="plus">
        <%= @title %>
      </.icon_button_>
    """
  end

  defp icon_button_(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:color, :icon, :inner_block, :class, :disabled]))
      |> Enum.into(%{class: "", disabled: false, inner_block: nil})

    ~H"""
    <button type="button" class={classes("btn-tertiary flex items-center p-1 font-sans rounded-lg hover:opacity-75 transition-colors text-#{@color} #{@class}", %{"opacity-50 hover:opacity-30 hover:cursor-not-allowed" => @disabled})}} disabled={@disabled} {@rest}>
      <.icon name={@icon} class={classes("w-3 h-3 fill-current text-#{@color}", %{"mr-1" => @inner_block})} />
      <%= if @inner_block do %>
        <%= render_block(@inner_block) %>
      <% end %>
    </button>
    """
  end
end
