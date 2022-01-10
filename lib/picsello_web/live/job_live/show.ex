defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, ClientMessage, BookingProposal, Package}

  import PicselloWeb.JobLive.Shared,
    only: [
      assign_job: 2,
      assign_proposal: 1,
      notes: 1,
      shoot_details: 1,
      status_badge: 1,
      subheader: 1,
      proposal_details: 1
    ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_job(job_id)
    |> assign_inbox_count()
    |> assign_proposal()
    |> subscribe_inbound_messages()
    |> ok()
  end

  def overview_card(assigns) do
    button_click = assigns[:button_click]

    ~H"""
      <li {testid("overview-#{@title}")} class="flex flex-col justify-between p-4 border rounded-lg">
        <div>
          <div class="mb-6 font-bold">
            <.icon name={@icon} class="inline w-5 h-6 mr-2 stroke-current" />
            <%= @title %>
          </div>

          <%= render_block(@inner_block) %>
        </div>

        <%= if @button_text do %>
          <button
            type="button"
            class="w-full p-2 mt-6 text-sm text-center border rounded-lg border-base-300"
            phx-click={button_click}
          >
            <%= @button_text %>
          </button>
        <% end %>
      </li>
    """
  end

  def gallery_overview_card(%{gallery: gallery} = assigns) do
    attrs =
      case Picsello.Galleries.gallery_current_status(gallery) do
        :none_created ->
          %{
            button_text: "Upload photo",
            button_click: "create-gallery",
            inner_block: fn _, _ -> "Looks like you need to upload photos." end
          }

        :upload_in_progress ->
          %{
            button_text: false,
            inner_block: fn _, _ -> "Photos currently uploading" end
          }

        :ready ->
          %{
            button_text: "View Gallery",
            button_click: "view-gallery",
            inner_block: fn _, _ -> "#{gallery.total_count} photos" end
          }

        :deactivated ->
          %{}
      end

    assigns
    |> Map.merge(attrs)
    |> overview_card()
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
  def handle_event("view-gallery", _, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_show_path(socket, :show, job.gallery.id))
      |> noreply()

  @impl true
  def handle_event("create-gallery", _, %{assigns: %{job: job}} = socket) do
    {:ok, gallery} =
      Picsello.Galleries.create_gallery(%{
        job_id: job.id,
        name: Job.name(job)
      })

    socket
    |> push_redirect(to: Routes.gallery_show_path(socket, :upload, gallery.id))
    |> noreply()
  end

  @impl true
  def handle_event("open-inbox", _, %{assigns: %{job: job}} = socket) do
    socket
    |> push_redirect(to: Routes.inbox_path(socket, :show, job.id))
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

  def handle_info(
        {:inbound_messages, message},
        %{assigns: %{inbox_count: count, job: job}} = socket
      ) do
    count = if message.job_id == job.id, do: count + 1, else: count

    socket
    |> assign(:inbox_count, count)
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

  defp assign_inbox_count(%{assigns: %{job: job}} = socket) do
    count =
      Job.by_id(job.id)
      |> ClientMessage.unread_messages()
      |> Repo.aggregate(:count)

    socket |> assign(:inbox_count, count)
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end
end
