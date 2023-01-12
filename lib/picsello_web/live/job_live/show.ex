defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Galleries, Job, Repo, PaymentSchedules}

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
      presign_entry: 2,
      shoot_details_section: 1,
      validate_payment_schedule: 1,
      title_header: 1,
      process_cancel_upload: 2,
      renew_uploads: 3
    ]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    auto_upload: true,
    external: &presign_entry/2,
    progress: &__MODULE__.handle_progress/3,
    max_entries: 2,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size))
  ]

  @impl true
  def mount(%{"id" => job_id} = assigns, _session, socket) do
    socket
    |> assign_job(job_id)
    |> assign(:request_from, assigns["request_from"])
    |> assign(:collapsed_sections, [])
    |> then(fn %{assigns: %{job: job}} = socket ->
      payment_schedules = job |> Repo.preload(:payment_schedules) |> Map.get(:payment_schedules)

      socket
      |> assign(payment_schedules: payment_schedules)
      |> assign(:invalid_entries, [])
      |> assign(:invalid_entries_errors, %{})
      |> allow_upload(:documents, @upload_options)
      |> validate_payment_schedule()
    end)
    |> ok()
  end

  defp orders_attrs(%Job{gallery: gallery}, orders_count) do
    cond do
      is_nil(gallery) ->
        %{
          button_text: "Setup gallery",
          button_click: "create-gallery",
          button_disabled: false,
          text: "You need to set your gallery up before clients can order"
        }

      orders_count == 0 ->
        %{
          button_text: "View orders",
          button_click: "#",
          button_disabled: true,
          text: "No orders to view"
        }

      true ->
        %{
          button_text: "View orders",
          button_click: "view-orders",
          button_disabled: false,
          text: "#{ngettext("1 order", "%{count} orders", orders_count)} to view from your client"
        }
    end
  end

  def gallery_attrs(%Job{gallery: gallery}) do
    case Picsello.Galleries.gallery_current_status(gallery) do
      :none_created ->
        %{
          button_text: "Upload photos",
          button_click: "create-gallery",
          button_disabled: false,
          text: "Looks like you need to upload photos."
        }

      :deactivated ->
        %{
          button_text: "View gallery",
          button_click: "view-gallery",
          button_disabled: true,
          text: "Gallery is disabled"
        }

      :selections_available ->
        %{
          button_text: "Go to gallery",
          button_click: "view-gallery",
          button_disabled: false,
          text: "Your client's prooflist is in!"
        }

      _ ->
        photos_count = Galleries.get_gallery_photos_count(gallery.id)

        %{
          button_text: "View gallery",
          button_click: "view-gallery",
          button_disabled: false,
          text: "#{photos_count} #{ngettext("photo", "photos", photos_count)}"
        }
    end
  end

  @impl true
  def handle_event("confirm_job_complete", %{}, socket) do
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
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

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

  def handle_event("view-gallery", _, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, job.gallery.id))
      |> noreply()

  def handle_event("view-orders", _, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.transaction_path(socket, :transactions, job.id))
      |> noreply()

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

  def handle_event(
        "cancel-upload",
        %{"ref" => ref},
        socket
      ) do
    socket
    |> process_cancel_upload(ref)
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

  def handle_progress(
        :documents,
        entry,
        %{
          assigns: %{
            job: %{documents: documents} = job,
            uploads: %{documents: %{entries: entries}}
          }
        } = socket
      ) do
    if entry.done? do
      key = Job.document_path(entry.client_name, entry.uuid)

      job =
        Picsello.Job.document_changeset(job, %{
          documents: [
            %{name: entry.client_name, url: key}
            | Enum.map(documents, &%{name: &1.name, url: &1.url})
          ]
        })
        |> Repo.update!()

      entries
      |> Enum.reject(&(&1.uuid == entry.uuid))
      |> renew_uploads(entry, socket)
      |> assign(:job, job)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
end
