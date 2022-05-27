defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, PaymentSchedules}

  import PicselloWeb.JobLive.Shared,
    only: [
      assign_job: 2,
      booking_details_section: 1,
      card: 1,
      communications_card: 1,
      history_card: 1,
      package_details_card: 1,
      private_notes_card: 1,
      section: 1,
      shoot_details_section: 1,
      title_header: 1
    ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_job(job_id)
    |> assign(:collapsed_sections, [])
    |> ok()
  end

  def gallery_attrs(%Job{gallery: gallery}) do
    case Picsello.Galleries.gallery_current_status(gallery) do
      :none_created ->
        %{
          button_text: "Upload photo",
          button_click: "create-gallery",
          button_disabled: false,
          text: "Looks like you need to upload photos."
        }

      :deactivated ->
        %{
          button_text: "View Gallery",
          button_click: "view-gallery",
          button_disabled: true,
          text: "Gallery is disabled"
        }

      _ ->
        %{
          button_text: "View Gallery",
          button_click: "view-gallery",
          button_disabled: false,
          text: "#{gallery.total_count || 0} photos"
        }
    end
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
  def handle_event("open-stripe", _, %{assigns: %{job: job, current_user: current_user}} = socket) do
    client = job |> Repo.preload(:client) |> Map.get(:client)

    socket
    |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/customers/#{client.stripe_customer_id}"
    )
    |> noreply()
  end

  @impl true
  def handle_event("view-gallery", _, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, job.gallery.id))
      |> noreply()

  @impl true
  def handle_event("create-gallery", _, %{assigns: %{job: job}} = socket) do
    {:ok, gallery} =
      Picsello.Galleries.create_gallery(%{
        job_id: job.id,
        name: Job.name(job)
      })

    socket
    |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery.id))
    |> noreply()
  end

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
