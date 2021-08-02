defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Shoot, Repo, BookingProposal, Accounts}

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign(:stripe_status, :loading)
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  @impl true
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.NewComponent,
        assigns |> Map.take([:current_user, :job])
      )
      |> noreply()

  @impl true
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

  @impl true
  def handle_event("edit-job", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.JobLive.EditComponent,
        assigns |> Map.take([:current_user, :package, :job])
      )
      |> noreply()

  @impl true
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

  @impl true
  def handle_event("send-proposal", %{}, %{assigns: %{job: job}} = socket) do
    case BookingProposal.create_changeset(%{job_id: job.id}) |> Repo.insert() do
      {:ok, proposal} ->
        token = Phoenix.Token.sign(PicselloWeb.Endpoint, "PROPOSAL_ID", proposal.id)
        url = Routes.booking_proposal_url(socket, :show, token)
        %{client: client} = job |> Repo.preload(:client)
        Accounts.UserNotifier.deliver_booking_proposal(client, url)

        socket
        |> put_flash(:info, "#{Job.name(job)} booking proposal was sent.")
        |> push_redirect(to: Routes.job_path(socket, :index))
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to create booking proposal. Please try again.")
        |> noreply()
    end
  end

  @impl true
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

  @impl true
  def handle_info({:update, %{package: _package} = assigns}, socket),
    do: socket |> assign(assigns) |> assign_shoots() |> noreply()

  @impl true
  def handle_info({:update, assigns}, socket),
    do: socket |> assign(assigns) |> noreply()

  @impl true
  def handle_info({:stripe_status, status}, socket),
    do: socket |> assign(:stripe_status, status) |> noreply()

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Repo.get!(job_id)
      |> Repo.preload([:client, :package])

    socket
    |> assign(
      job: job |> Map.drop([:package]),
      package: job.package
    )
    |> assign_shoots()
  end

  defp assign_shoots(
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

  defp assign_shoots(socket), do: socket |> assign(shoots: [])

  defp assign_proposal(%{assigns: %{job: %{id: job_id}}} = socket) do
    proposal = BookingProposal.last_for_job(job_id)
    socket |> assign(proposal: proposal)
  end
end
