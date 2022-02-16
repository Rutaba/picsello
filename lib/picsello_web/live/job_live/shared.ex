defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  alias Picsello.{
    Job,
    Shoot,
    ClientMessage,
    Repo,
    BookingProposal,
    Messages,
    Notifiers.ClientNotifier,
    Package,
    PaymentSchedules,
    Accounts.User
  }

  alias PicselloWeb.Router.Helpers, as: Routes
  require Ecto.Query

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  import PicselloWeb.FormHelpers
  import Phoenix.HTML.Form
  use Phoenix.Component

  def handle_event(
        "edit-shoot-details",
        %{"shoot-number" => shoot_number},
        %{assigns: %{shoots: shoots} = assigns} = socket
      ) do
    shoot_number = shoot_number |> String.to_integer()

    shoot = shoots |> Enum.into(%{}) |> Map.get(shoot_number)

    socket
    |> open_modal(
      PicselloWeb.ShootLive.EditComponent,
      assigns
      |> Map.take([:current_user, :job])
      |> Map.merge(%{
        shoot: shoot,
        shoot_number: shoot_number
      })
    )
    |> noreply()
  end

  def handle_event(
        "open-proposal",
        %{"action" => "" <> action},
        socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.Show.open_page_modal(action, true)
    |> noreply()
  end

  def handle_event(
        "open-proposal",
        %{},
        %{assigns: %{proposal: %{id: proposal_id}}} = socket
      ),
      do: socket |> redirect(to: BookingProposal.path(proposal_id)) |> noreply()

  def handle_event(
        "open-notes",
        %{},
        socket
      ) do
    socket
    |> PicselloWeb.JobLive.Shared.NotesModal.open()
    |> noreply()
  end

  def handle_event("open-compose", %{}, socket),
    do: socket |> PicselloWeb.ClientMessageComponent.open() |> noreply()

  def handle_event("open-inbox", _, %{assigns: %{job: job}} = socket) do
    socket
    |> push_redirect(to: Routes.inbox_path(socket, :show, job.id))
    |> noreply()
  end

  def handle_info({:action_event, "open_email_compose"}, socket) do
    socket |> PicselloWeb.ClientMessageComponent.open() |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{assigns: %{job: %{client: client} = job}} = socket
      ) do
    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, client.email) do
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Email sent",
        subtitle: "Yay! Your email has been successfully sent"
      })
      |> noreply()
    else
      _error ->
        socket |> put_flash(:error, "Something went wrong") |> close_modal() |> noreply()
    end
  end

  def handle_info(
        {:update, %{shoot_number: shoot_number, shoot: new_shoot}},
        %{assigns: %{shoots: shoots}} = socket
      ) do
    socket
    |> assign(
      shoots: shoots |> Enum.into(%{}) |> Map.put(shoot_number, new_shoot) |> Map.to_list()
    )
    |> noreply()
  end

  def handle_info({:update, %{package: _package} = assigns}, socket),
    do: socket |> assign(assigns) |> assign_shoots() |> noreply()

  def handle_info({:update, assigns}, socket),
    do: socket |> assign(assigns) |> noreply()

  def handle_info(
        {:inbound_messages, message},
        %{assigns: %{inbox_count: count, job: job}} = socket
      ) do
    count = if message.job_id == job.id, do: count + 1, else: count

    socket
    |> assign(:inbox_count, count)
    |> noreply()
  end

  def assign_shoots(
        %{assigns: %{package: %{shoot_count: shoot_count}, job: %{id: job_id}}} = socket
      ) do
    shoots = Shoot.for_job(job_id) |> Repo.all()

    socket
    |> assign(
      shoots:
        for(
          shoot_number <- 1..shoot_count,
          do: {shoot_number, Enum.at(shoots, shoot_number - 1)}
        )
    )
  end

  def assign_shoots(socket), do: socket |> assign(shoots: [])

  def assign_proposal(%{assigns: %{job: %{id: job_id}}} = socket) do
    proposal = BookingProposal.last_for_job(job_id) |> Repo.preload(:answer)
    socket |> assign(proposal: proposal)
  end

  defp assign_inbox_count(%{assigns: %{job: job}} = socket) do
    count =
      Job.by_id(job.id)
      |> ClientMessage.unread_messages()
      |> Repo.aggregate(:count)

    socket |> subscribe_inbound_messages() |> assign(:inbox_count, count)
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end

  @spec status_badge(%{job_status: %Picsello.JobStatus{}, class: binary}) ::
          %Phoenix.LiveView.Rendered{}
  def status_badge(%{job_status: %{current_status: status, is_lead: is_lead}} = assigns) do
    {label, color} = status_content(is_lead, status)

    assigns =
      assigns
      |> Enum.into(%{
        label: label,
        color: color,
        class: ""
      })

    ~H"""
      <.badge class={@class} color={@color}>
        <%= @label %>
      </.badge>
    """
  end

  def status_content(_, :archived), do: {"Archived", :gray}
  def status_content(_, :completed), do: {"Completed", :green}
  def status_content(false, _), do: {"Active", :blue}
  def status_content(true, :not_sent), do: {"Created", :blue}
  def status_content(true, :sent), do: {"Awaiting Acceptance", :blue}
  def status_content(true, :accepted), do: {"Awaiting Contract", :blue}

  def status_content(true, :signed_with_questionnaire),
    do: {"Awaiting Questionnaire", :blue}

  def status_content(true, status) when status in [:signed_without_questionnaire, :answered],
    do: {"Awaiting Payment", :blue}

  def status_content(_, status), do: {status |> Phoenix.Naming.humanize(), :blue}

  @spec subheader(%{package: %Picsello.Package{}, job: %Picsello.Job{}}) ::
          %Phoenix.LiveView.Rendered{}
  def subheader(assigns) do
    ~H"""
    <div {testid("subheader")} class="p-6 pt-2 lg:pt-6 lg:pb-0 grid center-container bg-blue-planning-100 gap-5 lg:grid-cols-2 lg:bg-white" {intro_hints_only("intro_hints_only")}>
      <div class="flex flex-col lg:items-center lg:flex-row">
        <%= if @package do %>
          <div class="flex justify-between min-w-0 lg:flex-row lg:justify-start">
            <div class="flex min-w-0"><span class="font-bold truncate" ><%= @package.name %></span>—<span class="flex-shrink-0"><%= @job.type |> Phoenix.Naming.humanize() %></span></div>
            <span class="ml-2 font-bold lg:ml-6"><%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %></span>
          </div>

          <%= if Job.lead?(@job) do %>
            <.icon_button title="Package settings" color="blue-planning-300" icon="gear" phx-click="edit-package" class="mt-2 lg:mt-0 w-max lg:ml-6">
              Package settings <.intro_hint content="You can change your package settings here. If you want, you can make changes specific to this lead, and they won’t change the package template." class="ml-1" />
            </.icon_button>
          <% end %>
        <% end %>
      </div>

      <hr class="border-white lg:hidden lg:col-span-2"/>

      <div class="flex flex-col min-w-0 lg:flex-row lg:justify-end">
        <span class="mb-3 mr-6 font-bold lg:mb-0 whitespace-nowrap"><%= @job.client.name %></span>

        <div class="flex">
          <a href={"tel:#{@job.client.phone}"} class="flex items-center mr-4 text-xs whitespace-nowrap lg:text-blue-planning-300">
            <.circle radius="7" class="mr-2">
              <.icon name="phone-outline" class="text-white stroke-current" width="12" height="10" />
            </.circle>

            <%= @job.client.phone %>
          </a>

          <a href="#" phx-click="open-compose" class="flex items-center min-w-0 text-xs lg:text-blue-planning-300">
            <span class="flex-shrink-0">
              <.circle radius="7" class="mr-2">
              <.icon name="envelope-outline" class="text-white stroke-current" width="12" height="10" />
              </.circle>
            </span>
            <span class="truncate"><%= @job.client.email %></span>
          </a>
        </div>
      </div>

      <hr class="hidden border-gray-200 lg:block col-span-2"/>
    </div>
    """
  end

  def overview_card(assigns) do
    assigns = assigns |> Enum.into(%{button_text: nil, button_click: nil, hint_content: nil})

    ~H"""
      <li {testid("overview-#{@title}")} class="flex flex-col justify-between p-4 border rounded-lg">
        <div>
          <div class="mb-4 font-bold">
            <.icon name={@icon} class="inline w-5 h-6 mr-2 stroke-current" />
            <%= @title %> <%= if @hint_content do %><.intro_hint content={@hint_content} /><% end %>
          </div>

          <%= render_block(@inner_block) %>
        </div>

        <%= if @button_text do %>
          <button
            type="button"
            class="w-full p-2 mt-4 text-sm text-center border rounded-lg border-base-300"
            phx-click={@button_click}
          >
            <%= @button_text %>
          </button>
        <% end %>
      </li>
    """
  end

  def circle(assigns) do
    radiuses = %{"7" => "w-7 h-7", "8" => "w-8 h-8"}

    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        radius_class: Map.get(radiuses, assigns.radius)
      })

    ~H"""
      <div class={"flex items-center justify-center rounded-full bg-blue-planning-300 #{@radius_class} #{@class}"}>
        <%= render_block(@inner_block) %>
      </div>
    """
  end

  @spec shoot_details(%{
          current_user: %Picsello.Accounts.User{},
          shoot_path: fun(),
          job: %Picsello.Job{},
          shoots: list(%Picsello.Shoot{}),
          socket: %Phoenix.LiveView.Socket{}
        }) :: %Phoenix.LiveView.Rendered{}
  def shoot_details(assigns) do
    ~H"""
    <ul class="text-left grid gap-5 lg:grid-cols-2 grid-cols-1">
    <%= for {shoot_number, shoot} <- @shoots do %>
      <li class="border rounded-lg hover:bg-blue-planning-100 hover:border-blue-planning-300">
        <%= if shoot do %>
          <%= live_redirect to: @shoot_path.(shoot_number), title: "shoot #{shoot_number}", class: "block w-full p-4 text-left" do %>
            <div class="flex items-center justify-between text-xl font-semibold">
              <div>
                <%= shoot.name %>
              </div>

              <.icon name="forth" class="w-4 h-4 stroke-current text-base-300" />
            </div>

            <div class="font-semibold text-blue-planning-300"> On <%= strftime(@current_user.time_zone, shoot.starts_at, "%B %d, %Y @ %I:%M %p") %> </div>

            <hr class="my-3 border-top">

            <span class="text-gray-400">
              <%= shoot_location(shoot) %>
            </span>
          <% end %>
        <% else %>
          <button title="Add shoot details" class="flex flex-col w-full h-full p-4 text-left" type="button" phx-click="edit-shoot-details" phx-value-shoot-number={shoot_number}>
            <.badge color={:red}>Missing information</.badge>

            <div class="flex items-center justify-between w-full mt-1 text-xl font-semibold">
              <div>
                Shoot <%= shoot_number %>
              </div>

              <.icon name="forth" class="w-4 h-4 stroke-current text-base-300" />
            </div>
          </button>
        <% end %>
      </li>
    <% end %>
    </ul>
    """
  end

  @spec notes(%{job: %Picsello.Job{}}) :: %Phoenix.LiveView.Rendered{}
  def notes(assigns) do
    ~H"""
      <div {testid("notes")} class="flex items-baseline justify-between p-4 my-8 border rounded-lg border-base-200" {testid("notes")}>
        <dl class="min-w-0">
          <dt class="font-bold">Private Notes</dt>
            <%= case @job.notes do %>
            <% nil -> %>
              <dd class="text-base-250"> Click edit to add a note </dd>
            <% notes -> %>
              <dd class="truncate"><%= String.split(notes, "\n") |> hd %></dd>
            <% end %>
        </dl>


        <%= case @job.notes do %>
        <% nil -> %>
          <.icon_button color="blue-planning-300" icon="pencil" phx-click="open-notes">Edit</.icon_button>
        <% _notes -> %>
          <button class="px-2 py-1 text-sm border rounded-lg border-blue-planning-300" type="button" phx-click="open-notes">
            View
          </button>
        <% end %>
      </div>
    """
  end

  @spec proposal_details(%{
          proposal: %BookingProposal{},
          current_user: %User{}
        }) :: %Phoenix.LiveView.Rendered{}
  def proposal_details(assigns) do
    ~H"""
      <div class="p-2 border rounded-lg">
        <div class="flex items-start justify-between p-2">
          <p>The following details were included in the booking proposal sent on <%= strftime(@current_user.time_zone, @proposal.inserted_at, "%B %d, %Y") %>.</p>
          <.icon_button icon="anchor" color="blue-planning-300" class="flex-shrink-0 ml-2 transition-colors" id="copy-client-link" data-clipboard-text={BookingProposal.url(@proposal.id)} phx-hook="Clipboard">
            <span>Client Link</span>
            <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
              Copied!
            </div>
          </.icon_button>
        </div>
        <div class={classes("mt-2 grid gap-5", %{"lg:grid-cols-4" => @proposal.questionnaire_id, "lg:grid-cols-3" => !@proposal.questionnaire_id})}>
          <.proposal_details_item title="Proposal" icon="document" status="Accepted" date={@proposal.accepted_at} current_user={@current_user} action="details" />
          <.proposal_details_item title="Standard Contract" icon="document" status="Signed" date={@proposal.signed_at} current_user={@current_user} action="contract" />
          <%= if @proposal.questionnaire_id do %>
            <.proposal_details_item title="Questionnaire" icon="document" status="Completed" date={if @proposal.answer, do: @proposal.answer.inserted_at} current_user={@current_user} action="questionnaire" />
          <% end %>
          <.proposal_details_item title="Invoice" icon="document" status="Completed" date={PaymentSchedules.remainder_paid_at(@job)} current_user={@current_user} action="invoice" />
        </div>
      </div>
    """
  end

  @spec proposal_details_item(%{
          title: binary(),
          icon: binary(),
          status: binary(),
          date: %DateTime{},
          current_user: %User{}
        }) :: %Phoenix.LiveView.Rendered{}
  def proposal_details_item(assigns) do
    ~H"""
    <a class="flex items-center p-2 rounded cursor-pointer hover:bg-blue-planning-100" href="#" phx-click="open-proposal" phx-value-action={@action} title={@title}>
      <.circle radius="8" class="flex-shrink-0">
        <.icon name={@icon} width="14" height="14" />
      </.circle>
      <div class="ml-2">
        <div class="flex items-center font-bold">
          <%= @title %>
          <.icon name="forth" class="w-3 h-3 ml-2 stroke-current text-base-300" />
        </div>
        <div class="text-xs text-gray-500">
          <%= if @date do %>
            <%= @status %> — <span class="whitespace-nowrap"><%= strftime(@current_user.time_zone, @date, "%B %d, %Y") %></span>
          <% else %>
            Pending
          <% end %>
        </div>
      </div>
    </a>
    """
  end

  def job_form_fields(assigns) do
    assigns = assigns |> Enum.into(%{email: nil, name: nil, phone: nil})

    ~H"""
    <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
      <%= inputs_for @form, :client, fn client_form -> %>
        <%= labeled_input client_form, :name, label: "Client Name", placeholder: "Elizabeth Taylor", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500", disabled: @name != nil %>
        <%= if @name != nil do %>
          <%= hidden_input client_form, :name %>
        <% end %>
        <%= labeled_input client_form, :email, type: :email_input, label: "Client Email", placeholder: "elizabeth.taylor@example.com", phx_debounce: "500", disabled: @email != nil %>
        <%= if @email != nil do %>
          <%= hidden_input client_form, :email %>
        <% end %>
        <%= labeled_input client_form, :phone, type: :telephone_input, label: "Client Phone", placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500", disabled: @phone != nil  %>
        <%= if @phone != nil do %>
          <%= hidden_input client_form, :phone %>
        <% end %>
      <% end %>

      <%= labeled_select @form, :type, for(type <- @job_types, do: {humanize(type), type}), label: "Type of Photography", prompt: "Select below" %>

      <div class="sm:col-span-2">
        <div class="flex items-center justify-between mb-2">
          <%= label_for @form, :notes, label: "Private Notes" %>
          <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(@form,:notes)}>
            Clear
          </.icon_button>
        </div>
        <%= input @form, :notes, type: :textarea, placeholder: "Optional notes", class: "w-full", phx_hook: "AutoHeight", phx_update: "ignore" %>
      </div>
    </div>
    """
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :leads}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Ecto.Query.preload([:client, :package, :job_status, :gallery])
      |> Repo.get!(job_id)

    if job.job_status.is_lead do
      socket
      |> do_assign_job(job)
    else
      push_redirect(socket, to: Routes.job_path(socket, :jobs, job_id))
    end
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :jobs}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Job.not_leads()
      |> Ecto.Query.preload([:client, :package, :job_status, :gallery])
      |> Repo.get!(job_id)

    do_assign_job(socket, job)
  end

  defp do_assign_job(socket, job) do
    socket
    |> assign(
      job: job,
      page_title: job |> Job.name(),
      package: job.package
    )
    |> assign_shoots()
    |> assign_proposal()
    |> assign_inbox_count()
  end
end
