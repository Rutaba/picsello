defmodule PicselloWeb.Live.ClientLive.JobHistory do
  @moduledoc false

  use PicselloWeb, :live_view
  require Ecto.Query

  import PicselloWeb.JobLive.Shared, only: [status_badge: 1]
  import PicselloWeb.Live.ClientLive.Shared

  alias Ecto.{Query, Changeset}
  alias PicselloWeb.{Helpers, ConfirmationComponent, ClientMessageComponent, JobLive.ImportWizard}
  alias Picsello.{Jobs, Job, Repo, Clients, Messages, Galleries}

  defmodule Pagination do
    @moduledoc false
    defstruct first_index: 1,
              last_index: 3,
              total_count: 0,
              limit: 3,
              after: nil,
              before: nil
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket
    |> get_client(id)
    |> assign_new(:pagination, fn -> %Pagination{} end)
    |> assign(:index, false)
    |> assign(:arrow_show, "contact details")
    |> assign(:job_types, Picsello.JobType.all())
    |> assign(:client_tags, %{})
    |> assign_clients_job(id)
    |> ok()
  end

  @impl true
  def handle_params(params, _, socket) do
    socket
    |> is_mobile(params)
    |> noreply()
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  @impl true
  def handle_event("create-gallery", %{"job_id" => job_id}, socket) do
    job_id = to_integer(job_id)

    gallery =
      case Galleries.get_gallery_by_job_id(job_id) do
        nil ->
          {:ok, gallery} =
            Galleries.create_gallery(%{
              job_id: job_id,
              name: Job.name(Jobs.get_job_by_id(job_id))
            })

          gallery

        gallery ->
          gallery
      end

    socket
    |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery.id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    client = clients |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => _id},
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "show_dropdown",
        %{"show_index" => show_index},
        %{assigns: %{index: index}} = socket
      ) do
    show_index = to_integer(show_index)

    socket
    |> assign(index: if(show_index == index, do: false, else: show_index))
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"cursor" => cursor, "direction" => direction},
        %{assigns: %{client_id: client_id}} = socket
      ) do
    update_fn =
      case direction do
        "back" -> &%{&1 | after: nil, before: cursor, first_index: &1.first_index - &1.limit}
        "forth" -> &%{&1 | after: cursor, before: nil, first_index: &1.first_index + &1.limit}
      end

    socket |> update(:pagination, update_fn) |> assign_clients_job(client_id) |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"per-page" => per_page},
        %{assigns: %{client_id: client_id}} = socket
      ) do
    limit = to_integer(per_page)

    socket
    |> assign(:pagination, %Pagination{limit: limit, last_index: limit})
    |> assign_clients_job(client_id)
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "open_compose",
        %{},
        %{assigns: %{index: index, jobs: jobs}} = socket
      ),
      do:
        socket
        |> assign(:job, Enum.at(jobs, index))
        |> open_compose()

  @impl true
  def handle_event("confirm_job_complete", %{}, %{assigns: %{index: index, jobs: jobs}} = socket),
    do:
      socket
      |> assign(:job, Enum.at(jobs, index))
      |> ConfirmationComponent.open(%{
        confirm_event: "complete_job",
        confirm_label: "Yes, complete",
        confirm_class: "btn-primary",
        subtitle:
          "After you complete the job this becomes read-only. This action cannot be undone.",
        title: "Are you sure you want to complete this job?",
        icon: "warning-blue"
      })
      |> noreply()

  @impl true
  def handle_info(
        {:message_composed, changeset},
        %{
          assigns: %{
            current_user: %{organization: %{name: organization_name}},
            job: %{id: job_id}
          }
        } = socket
      ) do
    flash =
      changeset
      |> Changeset.change(job_id: job_id, outbound: false, read_at: nil)
      |> Changeset.apply_changes()
      |> Repo.insert()
      |> case do
        {:ok, message} ->
          Messages.notify_inbound_message(message, Helpers)

          &ConfirmationComponent.open(&1, %{
            title: "Contact #{organization_name}",
            subtitle: "Thank you! Your message has been sent. We’ll be in touch with you soon.",
            icon: nil,
            confirm_label: "Send another",
            confirm_class: "btn-primary",
            confirm_event: "send_another"
          })

        {:error, _} ->
          &(&1 |> close_modal() |> put_flash(:error, "Message not sent."))
      end

    socket |> flash.() |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "send_another"}, socket), do: open_compose(socket)

  @impl true
  def handle_info({:confirm_event, "complete_job"}, %{assigns: %{job: job}} = socket) do
    case job |> Job.complete_changeset() |> Repo.update() do
      {:ok, job} ->
        socket
        |> assign(:job, job)
        |> put_flash(:success, "Job completed")
        |> push_redirect(to: Routes.client_path(socket, :job_history, job.client_id))

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Failed to complete job. Please try again.")
    end
    |> close_modal()
    |> noreply()
  end

  defp open_compose(%{assigns: %{job: job}} = socket),
    do:
      socket
      |> ClientMessageComponent.open(%{
        modal_title: "Send an email",
        show_client_email: true,
        show_subject: true,
        presets: [],
        send_button: "Send",
        client: Job.client(job)
      })
      |> noreply()

  defp get_client(%{assigns: %{current_user: user}} = socket, id) do
    case Clients.get_client(id, user) do
      nil ->
        socket |> redirect(to: "/clients")

      client ->
        socket |> assign(:client, client) |> assign(:client_id, client.id)
    end
  end

  defp assign_clients_job(
         %{
           assigns: %{
             pagination: pagination
           }
         } = socket,
         client_id
       ) do
    %{entries: jobs, metadata: metadata} =
      Jobs.get_client_jobs_query(client_id)
      |> Query.order_by(desc: :updated_at)
      |> Repo.paginate(
        pagination
        |> Map.take([:before, :after, :limit])
        |> Map.to_list()
        |> Enum.concat(cursor_fields: [updated_at: :desc])
      )

    socket
    |> assign(
      jobs: jobs,
      pagination: %{
        pagination
        | total_count: metadata.total_count,
          after: metadata.after,
          before: metadata.before,
          last_index: pagination.first_index + Enum.count(jobs) - 1
      }
    )
  end

  def table_item(assigns) do
    ~H"""
      <div class="py-0 md:py-2">
        <div class="font-bold">
          <%= Calendar.strftime(@job.inserted_at, "%m/%d/%y") %>
        </div>
        <div class={"font-bold w-full"}>
          <%= live_redirect to: Routes.job_path(@socket, :jobs, @job.id, %{"request_from" => "job_history"}) do %>
          <span class={classes("w-full text-blue-planning-300 underline", %{"truncate" => String.length(Job.name(@job)) > 29})}><%= Job.name(@job) %></span>
          <% end %>
        </div>
        <%= if @job.package do %>
          <div class="text-base-250 font-normal"><%= @job.package.name %></div>
        <% end %>
        <div class="text-base-250 font-normal mb-2">
          <%= Jobs.get_job_shooting_minutes(@job) %> minutes
        </div>
        <.status_badge job_status={@job.job_status} />
      </div>
    """
  end

  defp dropdown_item(%{icon: icon} = assigns) do
    assigns = Enum.into(assigns, %{class: nil, id: nil})

    icon_text_class =
      if icon in ["trash", "closed-eye"], do: "text-red-sales-300", else: "text-blue-planning-300"

    ~H"""
    <a {@link} class={"text-gray-700 block px-4 py-2 text-sm hover:bg-blue-planning-100 #{@class}"} role="menuitem" tabindex="-1" id={@id} }>
      <.icon name={icon} class={"w-4 h-4 fill-current #{icon_text_class} inline mr-1"} />
      <%= @title %>
    </a>
    """
  end
end
