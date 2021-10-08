defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  alias Picsello.{Job, Shoot, Repo, BookingProposal, Notifiers.ClientNotifier}

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component

  def handle_event(
        "edit-package",
        %{},
        %{assigns: %{current_user: current_user, job: job, package: %{id: package_id}}} = socket
      ),
      do:
        socket
        |> open_modal(
          PicselloWeb.PackageLive.EditComponent,
          %{current_user: current_user, job: job |> Map.put(:package_id, package_id)}
        )
        |> noreply()

  def handle_event("edit-job", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.LeadLive.EditComponent,
        assigns |> Map.take([:current_user, :package, :job])
      )
      |> noreply()

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
        %{},
        %{assigns: %{proposal: %{id: proposal_id}}} = socket
      ),
      do: socket |> redirect(to: BookingProposal.path(proposal_id)) |> noreply()

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

  @spec status_badge(%{job_status: %Picsello.JobStatus{}, class: binary}) ::
          %Phoenix.LiveView.Rendered{}
  def status_badge(%{job_status: %{current_status: status, is_lead: is_lead}} = assigns) do
    {label, color_style} = status_content(is_lead, status)

    assigns =
      assigns
      |> Enum.into(%{
        label: label,
        color_style: color_style,
        class: ""
      })

    ~H"""
    <span role="status" class={"px-2 py-0.5 text-xs font-semibold rounded #{@color_style} #{@class}"} >
      <%= @label %>
    </span>
    """
  end

  @status_colors %{
    gray: "bg-gray-200",
    blue: "bg-blue-planning-100 text-blue-planning-300 group-hover:bg-white",
    green: "bg-green-finances-100 text-green-finances-200"
  }

  def status_content(_, :archived), do: {"Archived", @status_colors.gray}
  def status_content(_, :completed), do: {"Completed", @status_colors.green}
  def status_content(false, _), do: {"Active", @status_colors.blue}
  def status_content(true, :not_sent), do: {"Created", @status_colors.blue}
  def status_content(true, :sent), do: {"Awaiting Acceptance", @status_colors.blue}
  def status_content(true, :accepted), do: {"Awaiting Contract", @status_colors.blue}

  def status_content(true, :signed_with_questionnaire),
    do: {"Awaiting Questionnaire", @status_colors.blue}

  def status_content(true, status) when status in [:signed_without_questionnaire, :answered],
    do: {"Awaiting Payment", @status_colors.blue}

  def status_content(_, status), do: {status |> Phoenix.Naming.humanize(), @status_colors.blue}
end
