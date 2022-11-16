defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Galleries, Job, Repo, PaymentSchedules}
  alias Picsello.Galleries.Workers.PhotoStorage

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
      validate_payment_schedule: 1,
      title_header: 1,
      check_max_entries: 1,
      check_dulplication: 2,
      renew_uploads: 3
    ]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    auto_upload: true,
    external: &__MODULE__.presign_entry/2,
    max_entries: 2,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size))
  ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_job(job_id)
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
        "validate",
        _,
        %{
          assigns: %{
            job: %{documents: documents},
            invalid_entries: invalid_entries,
            invalid_entries_errors: invalid_entries_errors
          }
        } = socket
      ) do
    ex_docs = Enum.map(documents, & &1.name)

    socket
    |> check_dulplication(ex_docs)
    |> check_max_entries()
    |> then(fn %{assigns: %{uploads: %{documents: %{entries: entries} = documents} = uploads}} ->
      {valid, new_invalid_entries} = Enum.split_with(entries, & &1.valid?)

      new_documents = Map.put(documents, :entries, valid) |> Map.put(:errors, [])
      uploads = Map.put(uploads, :documents, new_documents)

      socket
      |> assign(:uploads, uploads)
      |> assign(:invalid_entries, invalid_entries ++ new_invalid_entries)
      |> assign(
        :invalid_entries_errors,
        Map.new(documents.errors, & &1) |> Map.merge(invalid_entries_errors)
      )
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "retry",
        %{"ref" => ref},
        %{
          assigns: %{
            invalid_entries: invalid_entries,
            invalid_entries_errors: invalid_entries_errors,
            uploads: %{documents: documents}
          }
        } = socket
      ) do
    {[entry], new_invalid_entries} = Enum.split_with(invalid_entries, &(&1.ref == ref))

    [%{entry | valid?: true}]
    |> renew_uploads(entry, socket)
    |> assign(:invalid_entries, new_invalid_entries)
    |> assign(:invalid_entries_errors, Map.delete(invalid_entries_errors, ref))
    |> push_event("resume_upload", %{id: documents.ref})
    |> then(&__MODULE__.handle_event("validate", %{}, &1))
  end

  def handle_event(
        "cancel-upload",
        %{"ref" => ref},
        %{
          assigns: %{
            invalid_entries: invalid_entries,
            invalid_entries_errors: invalid_entries_errors
          }
        } = socket
      ) do
    socket
    |> assign(:invalid_entries, Enum.reject(invalid_entries, &(&1.ref == ref)))
    |> assign(:invalid_entries_errors, Map.delete(invalid_entries_errors, ref))
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

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  def presign_entry(
        entry,
        %{
          assigns: %{
            uploads: %{documents: %{entries: entries}},
            job: %{documents: documents} = job
          }
        } = socket
      ) do
    key = Job.document_path(job.id, entry.client_name)

    sign_opts = [
      expires_in: 144_000,
      bucket: @bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, @upload_options[:max_file_size]]]
    ]

    job =
      Picsello.Job.document_changeset(job, %{
        documents: [
          %{name: entry.client_name, url: key}
          | Enum.map(documents, &%{name: &1.name, url: &1.url})
        ]
      })
      |> Repo.update!()

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta,
     entries
     |> Enum.reject(&(&1.uuid == entry.uuid))
     |> renew_uploads(entry, socket)
     |> assign(:job, job)}
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
end
