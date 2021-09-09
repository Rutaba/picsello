defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  alias Picsello.{Job, Shoot, Repo, BookingProposal}

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers

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
    proposal = BookingProposal.last_for_job(job_id)
    socket |> assign(proposal: proposal)
  end
end