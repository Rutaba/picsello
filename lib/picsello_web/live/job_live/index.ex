defmodule PicselloWeb.JobLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  require Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [status_badge: 1]
  import PicselloWeb.Live.Shared, only: [pagination_index: 2]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  import PicselloWeb.Live.Shared.CustomPagination,
    only: [assign_pagination: 2, update_pagination: 2, reset_pagination: 2]

  alias Ecto.Changeset
  alias Picsello.{Job, Jobs, Repo, Payments}
  alias PicselloWeb.{Live.ClientLive.JobHistory, JobLive}

  @default_pagination_limit 6

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: action}} = socket) do
    socket
    |> assign_defaults()
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign_stripe_status()
    |> ok()
  end

  @impl true
  def handle_event(
        "apply-filter-status",
        %{"option" => status},
        socket
      ) do
    socket
    |> assign(:job_status, status)
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event(
        "apply-filter-type",
        %{"option" => type},
        socket
      ) do
    socket
    |> assign(:job_type, type)
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event(
        "apply-filter-sort_by",
        %{"option" => sort_by},
        socket
      ) do
    socket
    |> assign(:sort_by, sort_by)
    |> assign(
      :sort_col,
      if(sort_by not in ["oldest_lead", "newest_lead"],
        do: Enum.find(job_sort_options(), fn op -> op.id == sort_by end).column,
        else: Enum.find(lead_sort_options(), fn op -> op.id == sort_by end).column
      )
    )
    |> assign(
      :sort_direction,
      if(sort_by in ["oldest_job", "oldest_lead"], do: :asc, else: :desc)
    )
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event(
        "toggle-sort-direction",
        _,
        %{assigns: %{sort_direction: sort_direction}} = socket
      ) do
    socket
    |> assign(:sort_direction, if(sort_direction == :asc, do: :desc, else: :asc))
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        socket
      ) do
    search_phrase = String.trim(search_phrase)

    search_phrase =
      if String.length(search_phrase) > 0, do: String.downcase(search_phrase), else: nil

    socket
    |> assign(search_phrase: search_phrase)
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event("clear-search", _, socket) do
    socket
    |> assign(:search_phrase, nil)
    |> reassign_pagination_and_jobs()
  end

  @impl true
  def handle_event("view-job", %{"id" => id}, %{assigns: %{jobs: jobs}} = socket) do
    job = jobs |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> push_redirect(
      to: Routes.job_path(socket, if(job.job_status.is_lead, do: :leads, else: :jobs), id)
    )
    |> noreply()
  end

  @impl true
  def handle_event("view-client", %{"id" => id}, %{assigns: %{jobs: jobs}} = socket) do
    job = jobs |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> push_redirect(to: Routes.client_path(socket, :show, job.client_id))
    |> noreply()
  end

  @impl true
  def handle_event("view-galleries", %{"id" => id}, %{assigns: %{jobs: jobs}} = socket) do
    job = jobs |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> push_redirect(
      to: Routes.job_path(socket, if(job.job_status.is_lead, do: :leads, else: :jobs), id)
    )
    |> noreply()
  end

  @impl true
  def handle_event("create-lead", %{}, %{assigns: %{current_user: current_user}} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.JobLive.NewComponent,
        %{current_user: current_user}
      )
      |> noreply()

  @impl true
  def handle_event("import-job", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.ImportWizard, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  @impl true
  def handle_event(
        "page",
        %{"direction" => _direction} = params,
        socket
      ) do
    socket
    |> update_pagination(params)
    |> assign_jobs()
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"custom_pagination" => %{"limit" => _limit}} = params,
        socket
      ) do
    socket
    |> update_pagination(params)
    |> assign_jobs()
    |> noreply()
  end

  @impl true
  def handle_event("confirm_archive_lead", %{"id" => job_id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "archive-lead",
      confirm_label: "Yes, archive the lead",
      icon: "warning-orange",
      title: "Are you sure you want to archive this lead?",
      payload: %{job_id: job_id}
    })
    |> noreply()
  end

  @impl true
  def handle_event("confirm_unarchive_lead", %{"id" => job_id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "unarchive-lead",
      confirm_label: "Yes, unarchive the lead",
      icon: "warning-orange",
      title: "Are you sure you want to unarchive this lead?",
      payload: %{job_id: job_id}
    })
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  defdelegate handle_event(event, params, socket), to: JobHistory

  @impl true
  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  def handle_info({:confirm_event, "archive-lead", %{job_id: job_id}}, socket) do
    job = Jobs.get_job_by_id(job_id)

    case Jobs.archive_lead(job) do
      {:ok, _job} ->
        socket
        |> close_modal()
        |> put_flash(:success, "Lead has been archived")
        |> redirect(to: Routes.job_path(socket, :leads))
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Some error occurred")
        |> noreply()
    end
  end

  def handle_info({:confirm_event, "unarchive-lead", %{job_id: job_id}}, socket) do
    job = Jobs.get_job_by_id(job_id)

    case Jobs.unarchive_lead(job) do
      {:ok, _job} ->
        socket
        |> close_modal()
        |> put_flash(:success, "Lead has been unarchived")
        |> redirect(to: Routes.job_path(socket, :leads))
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Some error occurred")
        |> noreply()
    end
  end

  defdelegate handle_info(message, socket), to: JobLive.Shared

  def actions(assigns) do
    ~H"""
      <div class="flex items-center left-3 sm:left-8">
        <div class="" data-offset-x="0" phx-update="ignore" data-placement="bottom-end" phx-hook="Select" id={"manage-job-#{@job.id}"}>

          <button title="Manage" type="button" class="flex flex-shrink-0 p-1 text-2xl font-bold bg-white border rounded border-blue-planning-300 text-blue-planning-300">
            <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

            <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
          </button>

          <div class="z-10 flex flex-col hidden w-44 bg-white border rounded-lg shadow-lg popover-content">
            <%= for %{title: title, action: action, icon: icon} <- actions(), (@type == "jobs" and title != "Archive") || (@type == "leads" and title not in ["Complete", "Go to galleries"]) do %>
              <button title={title} type="button" phx-click={action} phx-value-id={@job.id} class={classes("flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100", %{"hidden" => @job.job_status.current_status == :archived and title == "Archive"})}>
                <.icon name={icon} class={classes("inline-block w-4 h-4 mr-3 fill-current", %{"text-red-sales-300" => icon == "trash", "text-blue-planning-300" => icon != "trash"})} />
                <%= title %>
              </button>
            <% end %>
            <%= if @job.job_status.current_status == :archived do %>
                <button title="Unarchive" type="button" phx-click="confirm_unarchive_lead" phx-value-id={@job.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                  <.icon name="plus" class="inline-block w-4 h-4 mr-3 text-blue-planning-300" />
                  Unarchive
                </button>
              <% end %>
          </div>

        </div>
      </div>
    """
  end

  def card_date(:jobs, "" <> time_zone, %Job{shoots: shoots}) do
    try do
      date =
        shoots
        |> Enum.map(& &1.starts_at)
        |> Enum.filter(&(DateTime.compare(&1, DateTime.utc_now()) == :gt))
        |> Enum.min(DateTime)

      strftime(time_zone, date, "%B %d, %Y @ %I:%M %p")
    rescue
      _e in Enum.EmptyError ->
        nil
    end
  end

  def card_date(:leads, _, _), do: nil

  def select_dropdown(assigns) do
    assigns =
      assigns
      |> Enum.into(%{class: ""})

    ~H"""
      <div class="flex flex-col w-full lg:w-auto mr-2 mb-3 lg:mb-0">
        <h1 class="font-extrabold text-sm flex flex-col whitespace-nowrap"><%= @title %></h1>
        <div class="flex">
          <div id={@id} class={classes("relative w-full lg:w-48 border-grey border p-2 cursor-pointer", %{"lg:w-64" => @id == "status" and @type == "lead", "rounded-l-lg" => @id == "sort_by", "rounded-lg" => @title == "Filter" or @id != "sort_by"})} data-offset-y="5" phx-hook="Select">
            <div {testid("dropdown_#{@id}")} class="flex flex-row items-center border-gray-700">
                <%= capitalize_per_word(String.replace(@selected_option, "_", " ")) %>
                <.icon name="down" class="w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
                <.icon name="up" class="hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
            </div>
            <ul class={"absolute z-30 hidden mt-2 bg-white toggle rounded-md popover-content border border-base-200 #{@class}"}>
              <%= for option <- @options_list do %>
                <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
                class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">

                  <button id={option.id} class={classes("album-select", %{"w-64" => @id == "status", "w-40" => @id != "status"})} phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
                  <%= if option.id == @selected_option do %>
                    <.icon name="tick" class="w-6 h-5 ml-auto mr-1 toggle-it text-green" />
                  <% end %>
                </li>
              <% end %>
            </ul>
          </div>
          <%= if @title == "Sort" do%>
            <div class="items-center flex border rounded-r-lg border-grey p-2">
              <button phx-click="toggle-sort-direction" disabled={@selected_option not in ["name", "shoot_date"]}>
                <%= if @sort_direction == :asc do %>
                  <.icon name="sort-vector" {testid("edit-link-button")} class={classes("blue-planning-300 w-5 h-5", %{"pointer-events-none opacity-40" => @selected_option not in ["name", "shoot_date"]})} />
                <% else %>
                  <.icon name="sort-vector-2" {testid("edit-link-button")} class={classes("blue-planning-300 w-5 h-5", %{"pointer-events-none opacity-40" => @selected_option not in ["name", "shoot_date"]})} />
                <% end %>
              </button>
            </div>
          <% end %>
        </div>
      </div>
    """
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end

  defp reassign_pagination_and_jobs(socket) do
    socket
    |> reset_pagination(%{limit: @default_pagination_limit, total_count: job_count(socket)})
    |> assign_jobs()
    |> noreply()
  end

  defp assign_jobs(
         %{
           assigns: %{
             current_user: current_user,
             live_action: action,
             job_status: status,
             job_type: type,
             sort_col: sort_by,
             sort_direction: sort_direction,
             search_phrase: search_phrase,
             pagination_changeset: pagination_changeset
           }
         } = socket
       ) do
    pagination = pagination_changeset |> Changeset.apply_changes()

    jobs =
      current_user
      |> Job.for_user()
      |> then(fn query ->
        case action do
          :leads -> query |> Job.leads() |> Job.not_booking()
          :jobs -> query |> Job.not_leads()
        end
      end)
      |> Jobs.get_jobs_by_pagination(
        %{
          status: status,
          type: type,
          sort_by: sort_by,
          sort_direction: sort_direction,
          search_phrase: search_phrase
        },
        pagination: pagination
      )
      |> Repo.all()

    socket
    |> assign(jobs: jobs)
    |> reset_pagination(%{
      total_count:
        if(pagination.total_count == 0,
          do: job_count(socket),
          else: pagination.total_count
        ),
      last_index: pagination.first_index + Enum.count(jobs) - 1
    })
  end

  defp job_count(%{
         assigns: %{
           live_action: action,
           current_user: user,
           job_status: status,
           job_type: type,
           sort_col: sort_by,
           sort_direction: sort_direction,
           search_phrase: search_phrase
         }
       }) do
    user
    |> Job.for_user()
    |> then(fn query ->
      case action do
        :leads -> query |> Job.leads() |> Job.not_booking()
        :jobs -> query |> Job.not_leads()
      end
    end)
    |> Jobs.get_jobs(%{
      status: status,
      type: type,
      sort_by: sort_by,
      sort_direction: sort_direction,
      search_phrase: search_phrase
    })
    |> Repo.all()
    |> Enum.count()
  end

  defp assign_defaults(socket) do
    socket
    |> assign_search()
    |> assign_pagination(@default_pagination_limit)
    |> assign(:job_status, "all")
    |> assign(:job_type, "all")
    |> then(fn %{assigns: %{live_action: live_action}} = socket ->
      if live_action == :leads do
        socket
        |> assign(:sort_by, "newest_lead")
        |> assign(:sort_col, :inserted_at)
        |> assign(:sort_direction, :desc)
      else
        socket
        |> assign(:sort_by, "shoot_date")
        |> assign(:sort_col, :starts_at)
        |> assign(:sort_direction, :desc)
      end
    end)
    |> assign(current_focus: -1)
    |> assign(:job_types, Picsello.JobType.all())
    |> assign_new(:selected_job, fn -> nil end)
    |> assign_jobs()
  end

  defp assign_search(socket) do
    socket
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_job, nil)
  end

  defp job_status_options do
    [
      %{title: "All", id: "all"},
      %{title: "Active", id: "active"},
      %{title: "Overdue", id: "overdue"},
      %{title: "Completed", id: "completed"},
      %{title: "Archived", id: "archived"}
    ]
  end

  defp lead_status_options do
    [
      %{title: "All", id: "all"},
      %{title: "Active Leads", id: "active_leads"},
      %{title: "Archived Leads", id: "archived_leads"},
      %{title: "Pending Invoice", id: "pending_invoice"},
      %{title: "Awaiting Questionnaire", id: "awaiting_questionnaire"},
      %{title: "Awaiting Contract", id: "awaiting_contract"},
      %{title: "New", id: "new"}
    ]
  end

  def job_type_options(job_types) do
    types =
      job_types
      |> Enum.map(fn type -> %{title: String.capitalize(type), id: type} end)

    [%{title: "All", id: "all"} | types]
  end

  defp job_sort_options do
    [
      %{title: "Name", id: "name", column: :name, direction: :desc},
      %{title: "Oldest Job", id: "oldest_job", column: :inserted_at, direction: :asc},
      %{title: "Newest Job", id: "newest_job", column: :inserted_at, direction: :desc},
      %{title: "Shoot Date", id: "shoot_date", column: :starts_at, direction: :desc}
    ]
  end

  defp lead_sort_options do
    [
      %{title: "Name", id: "name", column: :name, direction: :desc},
      %{title: "Oldest Lead", id: "oldest_lead", column: :inserted_at, direction: :asc},
      %{title: "Newest Lead", id: "newest_lead", column: :inserted_at, direction: :desc}
    ]
  end

  defp actions do
    [
      %{title: "Edit", action: "view-job", icon: "pencil"},
      %{title: "View client", action: "view-client", icon: "client-icon"},
      %{title: "Go to galleries", action: "view-galleries", icon: "photos-2"},
      %{title: "Send email", action: "open-compose", icon: "envelope"},
      %{title: "Complete", action: "complete-job", icon: "checkcircle"},
      %{title: "Archive", action: "confirm_archive_lead", icon: "trash"}
    ]
  end

  defp status_label(%{job_status: %{current_status: status}} = job, time_zone) do
    case status do
      :archived -> "Archived on #{get_date(job.updated_at, time_zone)}"
      :completed -> "Completed on #{get_date(job.completed_at, time_zone)}"
      :accepted -> "Awaiting on #{get_date(job.updated_at, time_zone)}"
      :signed_with_questionnaire -> "Awaiting on #{get_date(job.updated_at, time_zone)}"
      :signed_without_questionnaire -> "Pending on #{get_date(job.updated_at, time_zone)}"
      :answered -> "Pending on #{get_date(job.updated_at, time_zone)}"
      _ -> "Created on #{get_date(job.inserted_at, time_zone)}"
    end
  end

  defp get_date(date, time_zone), do: date |> format_date(time_zone)

  defp format_date(date, time_zone), do: strftime(time_zone, date, "%B %d, %Y")

  def capitalize_per_word(string) do
    String.split(string)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def search_sort_bar(assigns) do
    ~H"""
      <div {testid("search_filter_and_sort_bar")} class="flex flex-col px-5 center-container justify-between items-end px-1.5 lg:flex-row mb-0 md:mb-10">
        <div class="relative flex w-full lg:w-2/3 mr-2 mb-3 md:mb-0">
          <a {testid("close_search")} href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
            <%= if @search_phrase do %>
              <span phx-click="clear-search" class="cursor-pointer">
                <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
              </span>
            <% else %>
              <.icon name="search" class="w-4 ml-1 fill-current" />
            <% end %>
          </a>
          <%= form_tag("#", [phx_change: :search, phx_submit: :submit, class: "w-full"]) do %>
            <input disabled={!is_nil(@selected_job)} type="text" class="form-control w-full lg:w-64 text-input indent-6 bg-base-200 placeholder:text-black" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="100" spellcheck="false" placeholder={@placeholder} />
          <% end %>
        </div>
        <.select_dropdown class={classes("w-full", %{"w-64" => @type == "lead"})} type={@type} title={if @type == "job", do: 'Job Status', else: 'Lead Status'} id="status" selected_option={@job_status} options_list={if @type == "job", do: job_status_options(), else: lead_status_options()}/>

        <.select_dropdown class="w-full w-64 lg:w-auto" title={if @type == "job", do: 'Job Type', else: 'Lead Type'} id="type" selected_option={@job_type} options_list={job_type_options(@job_types)}/>

        <.select_dropdown class="w-full w-64 lg:w-auto" sort_direction={@sort_direction} title="Sort" id="sort_by" selected_option={@sort_by} options_list={if @type == "job", do: job_sort_options(), else: lead_sort_options()}/>

      </div>
    """
  end
end
