defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo, PaymentSchedules}
  alias Picsello.{Galleries, Galleries.Gallery}
  alias PicselloWeb.JobLive.GalleryTypeComponent

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
      card_title: 1,
      process_cancel_upload: 2,
      renew_uploads: 3
    ]

  import PicselloWeb.GalleryLive.Shared, only: [expired_at: 1, new_gallery_path: 2]

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
    |> assign(:new_gallery, nil)
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

  def gallery_attrs(%Gallery{type: type} = gallery, parent_has_orders? \\ false) do
    case Picsello.Galleries.gallery_current_status(gallery) do
      :none_created when type == :finals ->
        %{
          button_text: "Create Finals",
          button_click: "create-gallery",
          button_disabled: !parent_has_orders?,
          text: text(:finals, :none_created, parent_has_orders?),
          status: :none_created
        }

      :none_created ->
        %{
          button_text: "Start Setup",
          button_click: "create-gallery",
          button_disabled: false,
          text: "You don't have galleries for this job setup. Create one now!",
          status: :none_created
        }

      :no_photo when type == :finals ->
        %{
          button_text: "Upload Finals",
          button_click: "view-gallery",
          button_disabled: false,
          text: "Selects are ready",
          status: :no_photo
        }

      :no_photo ->
        %{
          button_text: "Upload Photos",
          button_click: "view-gallery",
          button_disabled: false,
          text: "Upload photos",
          status: :no_photo
        }

      :deactivated ->
        %{
          button_text: "View gallery",
          button_click: "view-gallery",
          button_disabled: true,
          text: "Gallery is disabled",
          status: :deactivated
        }

      status ->
        photos_count = Galleries.get_gallery_photos_count(gallery.id)

        %{
          button_text: button_text(type),
          button_click: "view-gallery",
          button_disabled: false,
          text: "#{photos_count} #{ngettext("photo", "photos", photos_count)}",
          status: status
        }
    end
  end

  defp text(:finals, :none_created, true), do: "Selects are ready"
  defp text(:finals, :none_created, false), do: "Need selects from client first"

  defp button_text(:proofing), do: "View selects"
  defp button_text(:finals), do: "View finals"
  defp button_text(_), do: "View gallery"

  defp galleries(%{galleries: []} = assigns) do
    %{
      button_text: button_text,
      button_click: button_click,
      button_disabled: button_disabled,
      text: text
    } = gallery_attrs(%Gallery{})

    ~H"""
    <div {testid("card-Gallery")}>
      <p><%= text %></p>
      <button class="btn-primary mt-4 intro-gallery" phx-click={button_click} disabled={button_disabled}>
        <%= button_text %>
      </button>
    </div>
    """
  end

  defp galleries(%{galleries: galleries} = assigns) do
    build_type = fn
      :finals -> :unlinked_finals
      type -> type
    end

    ~H"""
    <%= for %{name: name, type: type, child: child, orders: orders} = gallery <- galleries do %>
      <%= case type do %>
        <% :proofing -> %>
          <div {testid("card-proofing")} class="flex overflow-hidden border border-base-200 rounded-lg">
            <div class="flex flex-col w-full p-4">
              <.card_title title={name} gallery_type={type} color="black" gallery_card?={true} />
              <div class="flex justify-between w-full">
                <.card_content gallery={gallery} icon_name="proofing" title="Client Proofing" padding="pr-3" {assigns} />
                <div class="h-full w-px bg-base-200"/>
                <.card_content gallery={child || %Gallery{type: :finals, orders: []}} parent_id={gallery.id} parent_has_orders?={orders != []} icon_name="finals" title="Client Finals" padding="pl-3" {assigns} />
              </div>
            </div>
          </div>
        <% _ -> %>
          <.card title={name} gallery_card?={true} color="black" gallery_type={build_type.(type)}>
            <.inner_section {assigns} gallery={gallery} p_class="text-lg" btn_section_class="mt-[3.7rem]" link_class="font-semibold text-base" />
          </.card>
      <% end %>
    <% end %>
    """
  end

  defp card_content(assigns) do
    ~H"""
    <div class={"flex flex-col w-2/4 #{@padding}"}>
      <div class="flex">
        <div class="border p-1.5 rounded-full bg-base-200">
          <.icon name={@icon_name} class="w-4 h-4 stroke-2 fill-current text-blue-planning-300"/>
        </div>
        <span class="mt-0.5 ml-3 text-base font-bold"><%= @title %></span>
      </div>
      <.inner_section {assigns} btn_class="px-4" socket={@socket} />
    </div>
    """
  end

  defp inner_section(%{gallery: %{orders: orders}} = assigns) do
    assigns =
      Enum.into(
        assigns,
        %{
          p_class: "text-base h-12",
          btn_section_class: "mt-2",
          btn_class: "px-3",
          count: Enum.count(orders),
          parent_has_orders?: true,
          parent_id: nil
        }
      )

    ~H"""
    <%= case gallery_attrs(@gallery, @parent_has_orders?) do %>
      <% %{button_text: button_text, button_click: button_click, button_disabled: button_disabled, text: text, status: status} -> %>
        <p class={"text-base-250 font-normal #{@p_class}"}>
          <%= text %>
          <%= unless status in [:no_photo, :none_created] do %>
            - <%= if @count == 0, do: "No", else: @count %> orders
          <% end %>
        </p>
        <div {testid("card-buttons")} class={"flex self-end items-center gap-4 #{@btn_section_class}"} >
          <%= link "View Orders", to: (if @gallery.id, do: Routes.transaction_path(@socket, :transactions, @gallery.id), else: "#"), class: "font-normal text-sm text-blue-planning-300 underline #{@count == 0 && 'opacity-30 pointer-events-none'}" %>
          <button class={"btn-primary intro-gallery py-2 font-normal rounded-lg #{@btn_class}"} phx-click={button_click} phx-value-gallery_id={@gallery.id} phx-value-parent_id={@parent_id} disabled={button_disabled}><%= button_text %></button>
        </div>
    <% end %>
    """
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

  def handle_event("view-orders", _, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.transaction_path(socket, :transactions, job.id))
      |> noreply()

  @impl true
  def handle_event("view-gallery", %{"gallery_id" => gallery_id}, socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery_id))
      |> noreply()

  def handle_event("create-gallery", %{"parent_id" => parent_id}, socket) do
    send(self(), {:gallery_type, {"finals", parent_id}})

    noreply(socket)
  end

  @impl true
  def handle_event("create-gallery", _, %{assigns: %{job: job}} = socket) do
    socket
    |> open_modal(GalleryTypeComponent, %{job: job, from_job?: true})
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

  @impl true
  def handle_info(
        {:gallery_type, opts},
        %{assigns: %{job: job, current_user: %{organization_id: organization_id}}} = socket
      ) do
    {type, parent_id} = split(opts)

    {:ok, gallery} =
      Galleries.create_gallery(%{
        job_id: job.id,
        type: type,
        parent_id: parent_id,
        client_link_hash: UUID.uuid4(),
        name: Job.name(job) <> " #{Enum.count(job.galleries) + 1}",
        expired_at: expired_at(organization_id),
        albums: Galleries.album_params_for_new(type)
      })

    send(self(), {:redirect_to_gallery, gallery})

    socket
    |> assign(:new_gallery, gallery)
    |> noreply()
  end

  def handle_info({:redirect_to_gallery, gallery}, socket) do
    socket
    |> push_redirect(to: new_gallery_path(socket, gallery))
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

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

  defp split({type, parent_id}), do: {type, parent_id}
  defp split(type), do: {type, nil}
end
