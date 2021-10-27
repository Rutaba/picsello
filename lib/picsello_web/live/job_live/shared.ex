defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  alias Picsello.{
    Job,
    Shoot,
    Repo,
    BookingProposal,
    Notifiers.ClientNotifier,
    Package,
    Accounts.User
  }

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
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
        %{assigns: %{proposal: proposal}} = socket
      ) do
    Map.get(
      %{
        "questionnaire" => PicselloWeb.BookingProposalLive.QuestionnaireComponent,
        "details" => PicselloWeb.BookingProposalLive.ProposalComponent,
        "contract" => PicselloWeb.BookingProposalLive.ContractComponent
      },
      action
    )
    |> apply(:open_modal_from_proposal, [socket, proposal])
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

  def handle_info({:action_event, "open_email_compose"}, socket) do
    socket |> PicselloWeb.ClientMessageComponent.open() |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{assigns: %{job: %{client: client} = job}} = socket
      ) do
    with {:ok, message} <-
           message_changeset
           |> Ecto.Changeset.put_change(:job_id, job.id)
           |> Repo.insert(),
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

  def assign_job(%{assigns: %{current_user: current_user, live_action: action}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> then(fn query ->
        case action do
          :jobs -> query |> Job.not_leads()
          :leads -> query |> Job.leads()
        end
      end)
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package, :job_status])

    socket
    |> assign(
      job: job |> Map.drop([:package]),
      page_title: job |> Job.name(),
      package: job.package
    )
    |> assign_shoots()
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

  @badge_colors %{
    gray: "bg-gray-200",
    blue: "bg-blue-planning-100 text-blue-planning-300 group-hover:bg-white",
    green: "bg-green-finances-100 text-green-finances-200",
    red: "bg-red-sales-100 text-red-sales-300"
  }

  def badge(%{color: color} = assigns) do
    assigns =
      assigns |> Map.put(:color_style, Map.get(@badge_colors, color)) |> Enum.into(%{class: ""})

    ~H"""
    <span role="status" class={"px-2 py-0.5 text-xs font-semibold rounded #{@color_style} #{@class}"} >
      <%= render_block @inner_block %>
    </span>
    """
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
    <div {testid("subheader")} class="p-6 pt-2 lg:pt-6 lg:pb-0 grid center-container bg-blue-planning-100 gap-5 lg:grid-cols-2 lg:bg-white">
      <div class="flex flex-col lg:items-center lg:flex-row">
        <%= if @package do %>
          <div class="flex justify-between min-w-0 lg:flex-row lg:justify-start">
            <div class="flex min-w-0"><span class="font-bold truncate" ><%= @package.name %></span>—<span class="flex-shrink-0"><%= @job.type |> Phoenix.Naming.humanize() %></span></div>
            <span class="ml-2 font-bold lg:ml-6"><%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %></span>
          </div>

          <%= if Job.lead?(@job) do %>
            <.icon_button title="Package settings" color="blue-planning-300" icon="gear" phx-click="edit-package" class="mt-2 lg:mt-0 w-max lg:ml-6">
              Package settings
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

          <a href={"mailto:#{@job.client.email}"} class="flex items-center min-w-0 text-xs lg:text-blue-planning-300">
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
              <%= shoot.address || dyn_gettext shoot.location %>
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
end
