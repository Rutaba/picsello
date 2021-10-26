defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, Package}

  import PicselloWeb.JobLive.Shared, only: [assign_job: 2, assign_proposal: 1, status_badge: 1]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  def overview_card(assigns) do
    ~H"""
      <li class="flex flex-col justify-between p-4 border rounded-lg">
        <div>
          <div class="mb-6 font-bold">
            <.icon name={@icon} class="inline w-5 h-6 mr-2 stroke-current" />
            <%= @title %>
          </div>

          <%= render_block(@inner_block) %>
        </div>

        <button type="button" class="w-full p-2 mt-6 text-sm text-center border rounded-lg border-base-300" >
          <%= @button_text %>
        </button>
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

  def details_item(assigns) do
    ~H"""
    <a class="flex items-center p-2 rounded cursor-pointer hover:bg-blue-planning-100" phx-click="open-proposal" phx-value-action={@action} title={@title}>
      <.circle radius="8" class="flex-shrink-0">
        <.icon name={@icon} width="14" height="14" />
      </.circle>
      <div class="ml-2">
        <div class="flex items-center font-bold">
          <%= @title %>
          <.icon name="forth" class="w-3 h-3 ml-2 stroke-current text-base-300" />
        </div>
        <div class="text-xs text-gray-500"><%= @status %> — <span class="whitespace-nowrap"><%= strftime(@current_user.time_zone, @date, "%B %d, %Y") %></span></div>
      </div>
    </a>
    """
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "details"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.ProposalComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "contract"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.ContractComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-proposal",
        %{"action" => "questionnaire"},
        %{assigns: %{proposal: proposal}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.QuestionnaireComponent.open_modal_from_proposal(proposal)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-notes",
        %{},
        socket
      ) do
    socket
    |> PicselloWeb.JobLive.Shared.NotesModal.open()
    |> noreply()
  end

  @impl true
  def handle_event("manage", %{}, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> PicselloWeb.ActionSheetComponent.open(%{
        title: Job.name(job),
        actions:
          Enum.concat(
            [%{title: "Send an email", action_event: "open_email_compose"}],
            if(job.job_status.current_status == :completed,
              do: [],
              else: [%{title: "Complete job", action_event: "confirm_job_complete"}]
            )
          )
      })
      |> noreply()

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  def handle_info({:action_event, "confirm_job_complete"}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      confirm_event: "complete_job",
      confirm_label: "Yes, complete",
      confirm_class: "btn-primary",
      subtitle:
        "After you complete the job this becomes read-only. This action cannot be undone.",
      title: "Are you sure you want to complete this job?",
      icon: "warning-blue"
    })
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "complete_job"}, %{assigns: %{job: job}} = socket) do
    case job |> Job.complete_changeset() |> Repo.update() do
      {:ok, job} ->
        socket
        |> assign_job(job.id)
        |> close_modal()
        |> put_flash(:success, "Job completed")
        |> push_redirect(to: Routes.job_path(socket, :jobs))
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Failed to complete job. Please try again.")
        |> noreply()
    end
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
end
