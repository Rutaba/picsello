defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  require Ecto.Query

  use Phoenix.Component
  use Phoenix.HTML

  import Ecto.Query
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  import Phoenix.Component
  import PicselloWeb.FormHelpers
  import Phoenix.HTML.Form
  import PicselloWeb.Gettext, only: [ngettext: 3]
  import PicselloWeb.GalleryLive.Shared, only: [truncate_name: 2]

  alias Picsello.{
    Galleries,
    Job,
    Jobs,
    Client,
    Shoot,
    ClientMessage,
    Repo,
    BookingProposal,
    Messages,
    Notifiers.ClientNotifier,
    Package,
    PaymentSchedules,
    Galleries.Workers.PhotoStorage,
    Utils
  }

  alias PicselloWeb.{ConfirmationComponent, ClientMessageComponent}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias PicselloWeb.Router.Helpers, as: Routes

  @string_length 15

  def handle_event("copy-client-link", _, socket), do: socket |> noreply()

  def handle_event(
        "toggle-section",
        %{"section_id" => section_id},
        %{assigns: %{collapsed_sections: collapsed_sections}} = socket
      ) do
    collapsed_sections =
      if Enum.member?(collapsed_sections, section_id) do
        Enum.filter(collapsed_sections, &(&1 != section_id))
      else
        collapsed_sections ++ [section_id]
      end

    socket
    |> assign(:collapsed_sections, collapsed_sections)
    |> noreply()
  end

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
        %{"action" => "" <> action},
        socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.Show.open_page_modal(action, true)
    |> noreply()
  end

  def handle_event(
        "open-proposal",
        %{},
        %{assigns: %{proposal: %{id: proposal_id}}} = socket
      ),
      do: socket |> redirect(to: BookingProposal.path(proposal_id)) |> noreply()

  def handle_event(
        "open-notes",
        %{},
        socket
      ) do
    socket
    |> PicselloWeb.JobLive.Shared.NotesModal.open()
    |> noreply()
  end

  def handle_event(
        "open-compose",
        %{"client_id" => client_id},
        socket
      ),
      do: open_email_compose(socket, client_id)

  def handle_event(
        "open-compose",
        %{},
        %{assigns: %{index: index, jobs: jobs}} = socket
      ),
      do:
        socket
        |> assign(:job, Enum.at(jobs, index))
        |> open_email_compose()

  def handle_event(
        "open-compose",
        %{"id" => id},
        %{assigns: %{jobs: jobs}} = socket
      ),
      do:
        socket
        |> assign(:job, Enum.find(jobs, fn job -> job.id == to_integer(id) end))
        |> open_email_compose()

  def handle_event("open-compose", %{"id" => id}, socket), do: open_email_compose(socket, id)

  def handle_event(
        "open-mark-as-paid",
        %{},
        socket
      ) do
    socket
    |> PicselloWeb.JobLive.Shared.MarkPaidModal.open()
    |> noreply()
  end

  def handle_event("open-inbox", _, %{assigns: %{job: job}} = socket) do
    socket
    |> push_redirect(to: Routes.inbox_path(socket, :show, job.id))
    |> noreply()
  end

  def handle_event("delete_document", %{"name" => name, "document_id" => id} = _params, socket) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_docs",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete File?",
      subtitle:
        "Are you sure you wish to permanently delete #{name} from the job #{Job.name(socket.assigns.job)} ?",
      payload: %{documents_id: id}
    })
    |> noreply()
  end

  def handle_event("open_name_change", %{}, %{assigns: assigns} = socket) do
    params = Map.take(assigns, [:current_user, :job]) |> Map.put(:parent_pid, self())

    socket |> open_modal(PicselloWeb.Live.Profile.EditNameSharedComponent, params) |> noreply()
  end

  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    socket =
      socket
      |> assign(search_results: search(search_phrase, socket))
      |> assign(search_phrase: search_phrase)

    if search_phrase == "" || is_nil(search_phrase) do
      socket
      |> search_assigns()
      |> assign(:changeset, Job.new_job_changeset(Map.delete(changeset.changes, :client_id)))
    else
      socket
    end
    |> noreply()
  end

  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        %{assigns: %{job_changeset: job_changeset}} = socket
      ) do
    socket =
      socket
      |> assign(search_results: search(search_phrase, socket))
      |> assign(search_phrase: search_phrase)

    if search_phrase == "" || is_nil(search_phrase) do
      socket
      |> search_assigns()
      |> assign(
        :job_changeset,
        Job.new_job_changeset(Map.delete(job_changeset.changes, :client_id))
      )
    else
      socket
    end
    |> noreply()
  end

  def handle_event("new-client", _, socket) do
    socket
    |> assign(:new_client, true)
    |> search_assigns()
    |> noreply()
  end

  def handle_event("cancel-new-client", _, socket) do
    socket
    |> assign(:changeset, Picsello.Job.create_job_changeset(%{}))
    |> assign(:new_client, false)
    |> noreply()
  end

  def handle_event("clear-search", _, %{assigns: %{job_changeset: job_changeset}} = socket) do
    socket
    |> search_assigns()
    |> assign(
      :job_changeset,
      Job.new_job_changeset(Map.delete(job_changeset.changes, :client_id))
    )
    |> noreply()
  end

  def handle_event("clear-search", _, %{assigns: %{changeset: changeset}} = socket) do
    socket
    |> search_assigns()
    |> assign(:changeset, Job.new_job_changeset(Map.delete(changeset.changes, :client_id)))
    |> noreply()
  end

  def handle_event(
        "pick",
        %{"client_id" => client_id},
        %{assigns: %{search_results: search_results, job_changeset: job_changeset}} = socket
      ) do
    {current_focus, _} = Integer.parse(client_id)

    socket
    |> assign(:search_results, [])
    |> assign(:searched_client, Enum.find(search_results, &(&1.id == to_integer(client_id))))
    |> then(fn socket ->
      socket
      |> assign(:search_phrase, socket.assigns.searched_client.name)
    end)
    |> assign(
      :job_changeset,
      Job.new_job_changeset(Map.merge(job_changeset.changes, %{:client_id => client_id}))
    )
    |> assign(:current_focus, current_focus)
    |> noreply()
  end

  def handle_event(
        "pick",
        %{"client_id" => client_id},
        %{assigns: %{search_results: search_results, changeset: changeset}} = socket
      ) do
    {current_focus, _} = Integer.parse(client_id)

    socket
    |> assign(:search_results, [])
    |> assign(:searched_client, Enum.find(search_results, &(&1.id == to_integer(client_id))))
    |> then(fn socket ->
      socket
      |> assign(:search_phrase, socket.assigns.searched_client.name)
    end)
    |> assign(
      :changeset,
      Job.new_job_changeset(Map.merge(changeset.changes, %{:client_id => client_id}))
    )
    |> assign(:current_focus, current_focus)
    |> noreply()
  end

  # prevent search from submit
  def handle_event("submit", _, socket), do: socket |> noreply()

  # up
  def handle_event(
        "set-focus",
        %{"key" => "ArrowUp"},
        %{assigns: %{current_focus: current_focus}} = socket
      ) do
    socket
    |> assign(:current_focus, Enum.max([current_focus - 1, 0]))
    |> noreply()
  end

  # down
  def handle_event(
        "set-focus",
        %{"key" => "ArrowDown"},
        %{assigns: %{search_results: search_results, current_focus: current_focus}} = socket
      ) do
    socket
    |> assign(
      :current_focus,
      Enum.min([current_focus + 1, length(search_results) - 1])
    )
    |> noreply()
  end

  # enter
  def handle_event(
        "set-focus",
        %{"key" => "Enter"},
        %{assigns: %{search_results: search_results, current_focus: current_focus}} = socket
      ) do
    case Enum.at(search_results, current_focus) do
      nil ->
        socket |> noreply()

      search_phrase ->
        __MODULE__.handle_event("pick", %{"client_id" => "#{search_phrase.id}"}, socket)
    end
  end

  # fallback for non related search key strokes
  def handle_event("set-focus", _value, socket), do: noreply(socket)

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
    |> then(&__MODULE__.handle_event("validate", %{"_target" => ["documents"]}, &1))
  end

  def handle_event(
        "validate",
        %{"_target" => ["documents"]},
        %{
          assigns:
            %{
              invalid_entries: invalid_entries,
              invalid_entries_errors: invalid_entries_errors
            } = assigns
        } = socket
      ) do
    ex_docs = ex_docs(assigns)

    socket
    |> check_dulplication(ex_docs)
    |> check_max_entries()
    |> then(fn %{assigns: %{uploads: %{documents: %{entries: entries} = documents}}} ->
      {valid, new_invalid_entries} = Enum.split_with(entries, & &1.valid?)

      socket
      |> assign_documents(valid)
      |> assign(:invalid_entries, invalid_entries ++ new_invalid_entries)
      |> assign(
        :invalid_entries_errors,
        Map.new(documents.errors, & &1) |> Map.merge(invalid_entries_errors)
      )
    end)
    |> noreply()
  end

  def handle_event("complete-job", %{}, %{assigns: %{index: index, jobs: jobs}} = socket) do
    socket
    |> assign(:job, Enum.at(jobs, index))
    |> assign(:request_from, :clients)
    |> complete_job_component()
    |> noreply()
  end

  def handle_event("complete-job", %{"id" => id}, %{assigns: %{jobs: jobs}} = socket) do
    socket
    |> assign(:job, Enum.find(jobs, fn job -> job.id == to_integer(id) end))
    |> assign(:request_from, :jobs)
    |> complete_job_component()
    |> noreply()
  end

  def handle_event(
        "confirm-archive-unarchive",
        %{"id" => job_id},
        %{assigns: %{type: type}} = socket
      ) do
    job =
      if Map.get(socket.assigns, :jobs) do
        Enum.find(socket.assigns.jobs, fn job -> job.id == to_integer(job_id) end)
      else
        Jobs.get_job_by_id(job_id) |> Repo.preload([:job_status])
      end

    action_string =
      if job.job_status.current_status == :archived, do: "unarchive", else: "archive"

    socket
    |> ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "#{action_string}-entity",
      confirm_label: "Yes, #{action_string} the #{type.singular}",
      icon: "warning-orange",
      title: "Are you sure you want to #{action_string} this #{type.singular}?",
      payload: %{job_id: job_id}
    })
    |> noreply()
  end

  def handle_info({:confirm_event, "send_another"}, socket), do: open_email_compose(socket)

  def handle_info({:action_event, "open_email_compose"}, socket),
    do: open_email_compose(socket, socket.assigns.client.id)

  def handle_info(
        {:confirm_event, "delete_docs", %{documents_id: documents_id}},
        %{assigns: %{job: %{documents: documents} = job}} = socket
      ) do
    job =
      Ecto.Changeset.change(job, %{documents: Enum.reject(documents, &(&1.id == documents_id))})
      |> Repo.update!()

    socket
    |> close_modal()
    |> assign(:job, job)
    |> put_flash(:success, "Document deleted successfully!")
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "complete_job"},
        %{assigns: %{job: job, request_from: request_from} = assigns} = socket
      ) do
    case job |> Job.complete_changeset() |> Repo.update() do
      {:ok, job} ->
        socket
        |> assign(:job, job)
        |> put_flash(:success, "Job completed")
        |> push_redirect(
          to:
            cond do
              request_from == :jobs ->
                Routes.job_path(socket, :jobs)

              request_from == :clients ->
                Routes.client_path(socket, :job_history, job.client_id)

              true ->
                Routes.job_path(socket, Map.get(assigns, :live_action), job.id)
            end
        )

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Failed to complete job. Please try again.")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "archive-entity", %{job_id: job_id}},
        %{assigns: %{type: type} = assigns} = socket
      ) do
    job =
      if Map.get(assigns, :jobs) do
        Enum.find(assigns.jobs, fn job -> job.id == to_integer(job_id) end)
      else
        Jobs.get_job_by_id(job_id) |> Repo.preload([:job_status])
      end

    case Jobs.archive_job(job) do
      {:ok, _job} ->
        socket
        |> put_flash(
          :success,
          "#{String.capitalize(type.singular)} has been archived"
        )
        |> redirect(
          to:
            cond do
              Map.has_key?(assigns, :type) ->
                Routes.job_path(socket, String.to_atom(assigns.type.plural))

              Map.get(assigns, :live_action) in [:leads, :jobs] ->
                Routes.job_path(socket, Map.get(assigns, :live_action), job.id)

              true ->
                Routes.client_path(socket, :job_history, job.client_id)
            end
        )

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to archive, please try again")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "unarchive-entity", %{job_id: job_id}},
        %{assigns: %{type: type} = assigns} = socket
      ) do
    job =
      if Map.get(assigns, :jobs) do
        Enum.find(assigns.jobs, fn job -> job.id == to_integer(job_id) end)
      else
        Jobs.get_job_by_id(job_id) |> Repo.preload([:job_status])
      end

    case Jobs.unarchive_job(job) do
      {:ok, _job} ->
        socket
        |> put_flash(
          :success,
          "#{String.capitalize(type.singular)} has been unarchived"
        )
        |> redirect(
          to:
            cond do
              Map.has_key?(assigns, :type) ->
                Routes.job_path(socket, String.to_atom(assigns.type.plural))

              Map.get(assigns, :live_action) in [:leads, :jobs] ->
                Routes.job_path(socket, Map.get(assigns, :live_action), job.id)

              true ->
                Routes.client_path(socket, :job_history, job.client_id)
            end
        )

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to unarchive, please try again")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info({:confirm_event, "edit_package", %{assigns: assigns}}, socket) do
    socket
    |> open_modal(
      PicselloWeb.PackageLive.WizardComponent,
      assigns |> Map.take([:current_user, :job, :package])
    )
    |> assign_disabled_copy_link()
    |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{assigns: %{job: job}} = socket
      ) do
    job = job |> Repo.preload(:client)

    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, job.client.email) do
      socket
      |> ConfirmationComponent.open(%{
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
        %{assigns: %{shoots: shoots, job: job}} = socket
      ) do
    shoots = shoots |> Enum.into(%{}) |> Map.put(shoot_number, new_shoot) |> Map.to_list()

    socket
    |> assign(
      shoots: shoots,
      job: job |> Repo.preload(:shoots, force: true)
    )
    |> assign_payment_schedules()
    |> assign_disabled_copy_link()
    |> noreply()
  end

  def handle_info(
        {:update, %{questionnaire: _questionnaire}},
        %{assigns: %{package: package}} = socket
      ) do
    package = package |> Repo.preload(:questionnaire_template, force: true)

    socket
    |> assign(:package, package)
    |> put_flash(:success, "Questionnaire saved")
    |> noreply()
  end

  def handle_info({:update, %{job: job}}, socket) do
    socket
    |> assign(:job, job)
    |> put_flash(:success, "Job updated successfully")
    |> noreply()
  end

  def handle_info({:update, %{package: package}}, %{assigns: %{job: job}} = socket) do
    package =
      package
      |> Repo.preload([:contract, :questionnaire_template], force: true)

    socket
    |> assign(package: package, job: %{job | package: package, package_id: package.id})
    |> assign_shoots()
    |> assign_payment_schedules()
    |> assign_disabled_copy_link()
    |> put_flash(:success, "Package details saved sucessfully.")
    |> noreply()
  end

  def handle_info({:update, assigns}, socket),
    do:
      socket
      |> assign(assigns)
      |> assign_payment_schedules()
      |> assign_disabled_copy_link()
      |> noreply()

  def handle_info(
        {:inbound_messages, message},
        %{assigns: %{inbox_count: count, job: job}} = socket
      ) do
    count = if message.job_id == job.id, do: count + 1, else: count

    socket
    |> assign(:inbox_count, count)
    |> noreply()
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

  def assign_uploads(socket, upload_options) do
    socket
    |> allow_upload(:documents, upload_options)
    |> assign(:invalid_entries, [])
    |> assign(:invalid_entries_errors, %{})
  end

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  def presign_entry(entry, %{assigns: %{uploads: uploads}} = socket) do
    %{documents: %{max_file_size: max_file_size}} = uploads
    key = Job.document_path(entry.client_name, entry.uuid)

    sign_opts = [
      expires_in: 144_000,
      bucket: @bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, max_file_size]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  def process_cancel_upload(
        %{
          assigns: %{
            invalid_entries: invalid_entries,
            invalid_entries_errors: invalid_entries_errors,
            uploads: %{documents: documents}
          }
        } = socket,
        ref
      ) do
    socket
    |> assign_documents(Enum.reject(documents.entries, &(&1.ref == ref)))
    |> assign(:invalid_entries, Enum.reject(invalid_entries, &(&1.ref == ref)))
    |> assign(:invalid_entries_errors, Map.delete(invalid_entries_errors, ref))
  end

  @spec status_badge(%{:job => %{:job_status => map, optional(atom) => any}, optional(any) => any}) ::
          Phoenix.LiveView.Rendered.t()
  def status_badge(
        %{job: %{job_status: %{current_status: status, is_lead: is_lead}} = job} = assigns
      ) do
    job = job |> Repo.preload(:payment_schedules)

    badge =
      if not is_lead and
           Enum.any?(job.payment_schedules, fn schedule ->
             DateTime.compare(schedule.due_at, DateTime.utc_now()) == :lt and
               is_nil(schedule.paid_at)
           end),
         do: %{label: "Overdue", color: :red},
         else: status_content(is_lead, status)

    second_badge = second_badge(is_lead, status, badge.label)

    assigns =
      assigns
      |> Enum.into(%{
        label: badge.label,
        color: badge.color,
        class: ""
      })

    ~H"""
      <span>
        <.badge class={@class} color={@color}>
          <%= @label %>
        </.badge>
        <%= if second_badge do %>
          <.badge class={"ml-1 #{@class}"} color={second_badge.color}>
            <%= second_badge.label %>
          </.badge>
        <% end %>
      </span>
    """
  end

  def status_content(_, :archived), do: %{label: "Archived", color: :red}
  def status_content(false, :completed), do: %{label: "Completed", color: :green}
  def status_content(false, _), do: %{label: "Active", color: :blue}
  def status_content(true, :not_sent), do: %{label: "New", color: :blue}
  def status_content(true, :sent), do: %{label: "Active", color: :blue}
  def status_content(true, :accepted), do: %{label: "Awaiting Contract", color: :blue}

  def status_content(true, :signed_with_questionnaire),
    do: %{label: "Awaiting Questionnaire", color: :blue}

  def status_content(true, status) when status in [:signed_without_questionnaire, :answered],
    do: %{label: "Pending Invoice", color: :blue}

  def status_content(true, _), do: %{label: "Active", color: :blue}

  def status_content(_, status), do: %{label: status |> Phoenix.Naming.humanize(), color: :blue}

  def title_header(assigns) do
    ~H"""
    <h1 class="flex items-center mt-4 text-4xl font-bold md:justify-start">
      <div class="flex items-center max-w-4xl">
        <.live_link to={@back_path} class="rounded-full bg-base-200 flex items-center justify-center p-2.5 mt-2 mr-4">
          <.icon name="back" class="w-4 h-4 stroke-2"/>
        </.live_link>
        <%= Job.name @job %>
      </div>
      <div class="px-5">
        <button type="button" phx-click="open_name_change" class="bg-base-200 p-2 rounded-lg btn-tertiary">
          <.icon name="pencil" class="w-4 h-4 fill-current text-blue-planning-300" />
        </button>
      </div>
    </h1>
    """
  end

  def section(assigns) do
    assigns = assigns |> Enum.into(%{badge: 0})

    ~H"""
    <section {if @id == "gallery" && @anchor == "anchor-to-gallery", do: %{id: "gallery-anchor", phx_hook: "ScrollIntoView"}, else: %{}} class="sm:border sm:border-base-200 sm:rounded-lg mt-8 overflow-hidden">
      <div class="flex bg-base-200 px-4 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={@id}>
        <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center">
          <.icon name={@icon} class="w-5 h-5" />
        </div>
        <h2 class="text-2xl font-bold ml-3"><%= @title %></h2>
        <%= if @badge > 0 do %>
          <div {testid("section-badge")} class="ml-4 leading-none w-5 h-5 rounded-full pb-0.5 flex items-center justify-center text-xs bg-base-300 text-white">
            <%= @badge %>
          </div>
        <% end %>
        <div class="ml-auto">
          <%= if Enum.member?(@collapsed_sections, @id) do %>
            <.icon name="down" class="w-5 h-5 stroke-current stroke-2" />
          <% else %>
            <.icon name="up" class="w-5 h-5 stroke-current stroke-2" />
          <% end %>
        </div>
      </div>
      <div class={classes("p-6", %{"hidden" => Enum.member?(@collapsed_sections, @id)})}>
        <%= render_slot @inner_block %>
      </div>
    </section>
    """
  end

  def card(assigns) do
    assigns =
      Enum.into(assigns, %{
        class: "",
        color: "blue-planning-300",
        gallery_card?: false,
        gallery_type: nil
      })

    ~H"""
    <div {testid("card-#{@title}")} class={"flex overflow-hidden border border-base-200 rounded-lg #{@class}"}>
      <div class={"w-3 flex-shrink-0 border-r rounded-l-lg bg-#{@color} #{@gallery_card? && 'hidden'}"} />
      <div class="flex flex-col w-full p-4">
        <.card_title
        color={@color}
        title={@title}
        gallery_card?={@gallery_card?}
        gallery_type={@gallery_type}
        />
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def card_title(%{gallery_card?: true} = assigns) do
    ~H"""
    <div class="flex justify-between">
      <.card_title color={@color} title={@title}  />
      <h4 class="border rounded-md bg-base-200 px-2 mb-1.5 text-base-250 font-bold text-base"><%= Utils.capitalize_all_words(@gallery_type) %>
      <%= if @gallery_type == :unlinked_finals do %>
        <.intro_hint class="ml-2" content="<b>Note:</b> You had more than one finals album, within your proofing gallery. To keep your data safe, we have created a gallery to hold those and you can reorganize/reupload photos to the new/improved proofing gallery"/>
      <% end %>
      </h4>
    </div>
    """
  end

  def card_title(assigns) do
    ~H[<h3 class={"mb-2 mr-4 text-xl font-bold text-#{@color}"}><%= @title %></h3>]
  end

  def communications_card(assigns) do
    ~H"""
    <.card color="orange-inbox-300" title="Communications" class="md:col-span-2">
      <div {testid("inbox")} class="flex flex-col lg:flex-row">
        <div class="flex-1 text-base-250">
          Inbox
          <div class="flex border border-base-200 rounded-lg p-8 mt-4 justify-center">
            <span class={classes("w-7 h-7 flex items-center justify-center text-lg font-bold text-white rounded-full mr-2 pb-1", %{"bg-orange-inbox-300" => @inbox_count > 0,"bg-base-250" => @inbox_count <= 0})}>
              <%= @inbox_count %>
            </span>
            <span class={if @inbox_count > 0, do: "text-orange-inbox-300", else: "text-base-250"}>
              <%= ngettext "new message", "new messages", @inbox_count %>
            </span>
          </div>
          <div class="flex flex-col-reverse sm:flex-row justify-end mt-4">
            <button type="button" class="link mx-8 my-4" phx-click="open-inbox">
              Go to inbox
            </button>
            <button type="button" class="btn-primary intro-message" phx-click="open-compose" phx-value-client_id={@job.client_id}>
              Send message
            </button>
          </div>
        </div>
        <div class="my-8 border-t lg:my-0 lg:mx-8 lg:border-t-0 lg:border-l border-base-200"></div>
        <div class="flex flex-col flex-[0.5]">
          <span class="mb-1 font-bold"><%= @job.client.name %></span>
          <%= if @job.client.phone do %>
            <a href={"tel:#{@job.client.phone}"} class="flex items-center text-xs">
              <.icon name="phone" class="text-blue-planning-300 mr-2 w-4 h-4" />
              <span class="text-base-250"><%= @job.client.phone %></span>
            </a>
          <% end %>
          <a phx-click="open-compose" phx-value-client_id={@job.client_id} class="flex items-center text-xs mt-2 hover:cursor-pointer">
            <.icon name="envelope" class="text-blue-planning-300 mr-2 w-4 h-4" />
            <span class="text-base-250"><%= @job.client.email %></span>
          </a>
        </div>
      </div>
    </.card>
    """
  end

  def package_details_card(assigns) do
    ~H"""
    <.card title="Package details" class="h-52">
      <%= if @package do %>
        <p class="font-bold"><%= @package.name %></p>
        <p><%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %></p>
        <%= if @package.download_count > 0 do %>
          <p><%= ngettext "%{count} image", "%{count} images", @package.download_count %></p>
        <% end %>
        <%= unless @package |> Package.print_credits() |> Money.zero?() do %>
          <p><%= "#{Money.to_string(@package.print_credits, fractional_unit: false)} print credit" %></p>
        <% end %>
        <%= if !@job.is_gallery_only do %>
          <div class="mt-auto self-end relative py-1">
            <.icon_button color="blue-planning-300" phx-click="edit-package" icon="pencil" class="mt-auto" disabled={!Job.lead?(@job) || (@proposal && @proposal.signed_at)} title={if !Job.lead?(@job) || (@proposal && @proposal.signed_at), do: "Your client has already signed their proposal so package details are no longer editable.", else: "Edit package"}>
              Edit
            </.icon_button>
          </div>
        <% end %>
      <% else %>
        <p class="text-base-250">Click edit to add a package. You can come back to this later if your client isn’t ready for pricing quite yet.</p>
        <.icon_button color="blue-planning-300" icon="pencil" phx-click="add-package" class="mt-auto self-end">
          Edit
        </.icon_button>
      <% end %>
    </.card>
    """
  end

  def private_notes_card(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:content_class, fn -> "line-clamp-4" end)

    ~H"""
    <.card title="Private notes" class={"h-52 #{@class}"}>
      <%= if @job.notes do %>
        <p class={"whitespace-pre-line #{@content_class}"}><%= @job.notes %></p>
      <% else %>
        <p class={"text-base-250 #{@content_class}"}>Click edit to add a note about your client and any details you want to remember.</p>
      <% end %>
      <.icon_button color="blue-planning-300" icon="pencil" phx-click="open-notes" class="mt-auto self-end">
        Edit
      </.icon_button>
    </.card>
    """
  end

  def shoot_details_section(assigns) do
    ~H"""
    <.section id="shoot-details" icon="camera-check" title="Shoot details" collapsed_sections={@collapsed_sections}>
      <%= if is_nil(@package) do %>
        <p>You don’t have any shoots yet! If your client has a date but hasn’t decided on pricing, add a placeholder package for now.</p>

        <button {testid("add-package-from-shoot")} type="button" phx-click="add-package" class="mt-2 text-center btn-primary intro-add-package">
          Add a package
        </button>

      <% else %>
        <ul class="text-left grid gap-5 lg:grid-cols-2 grid-cols-1">
          <%= for {shoot_number, shoot} <- @shoots do %>
            <li {testid("shoot-card")} class="border rounded-lg hover:bg-blue-planning-100 hover:border-blue-planning-300">
              <%= if shoot do %>
                <%= live_redirect to: @shoot_path.(shoot_number), title: "shoot #{shoot_number}", class: "block w-full p-4 text-left" do %>
                  <div class="flex items-center justify-between text-xl font-semibold">
                    <div>
                      <%= shoot.name %>
                    </div>

                    <.icon name="forth" class="w-4 h-4 stroke-current text-base-300 stroke-2" />
                  </div>

                  <div class="font-semibold text-blue-planning-300"> On <%= strftime(@current_user.time_zone, shoot.starts_at, "%B %d, %Y @ %I:%M %p") %> </div>

                  <hr class="my-3 border-top">

                  <span class="text-gray-400">
                    <%= shoot_location(shoot) %>
                  </span>
                <% end %>
              <% else %>
                <button title="Add shoot details" class="flex flex-col w-full h-full p-4 text-left" type="button" phx-click="edit-shoot-details" phx-value-shoot-number={shoot_number}>
                  <.badge color={:red}>Missing information</.badge>

                  <div class="flex items-center justify-between w-full mt-1 text-xl font-semibold">
                    <div>
                      Shoot <%= shoot_number %>
                    </div>

                    <.icon name="forth" class="w-4 h-4 stroke-current text-base-300 stroke-2" />
                  </div>
                </button>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </.section>
    """
  end

  def booking_details_section(assigns) do
    assigns = assigns |> Enum.into(%{disabled_copy_link: false, string_length: @string_length})

    ~H"""
    <.section id="booking-details" icon="camera-laptop" title="Booking details" collapsed_sections={@collapsed_sections}>
      <.card title={if @proposal && (@proposal.sent_to_client || @proposal.accepted_at), do: "Here’s what you sent your client", else: "Here’s what you’ll be sending your client"}>
      <%= if(!@job.job_status.is_lead) do %>
      <div class="grid sm:grid-cols-2 gap-5 border border-base-200 rounded-lg my-5">
        <div class="flex flex-col p-4">
          <div class="flex flex-row font-bold">
            Additional files
          </div>
          <div class="flex flex-col">
          <%= if(@job.documents == nil || @job.documents == []) do %>
          <div class="p-12 text-gray-400 italic">No additional files have been uploaded</div>
          <% end %>
            <%= for document <- @job.documents do %>
            <div id={document.id} class="flex flex-row justify-between items-center">
              <a href={path_to_url(document.url)} target="_blank" rel="document">
                <dl class="flex items-center">
                  <dd>
                  <.icon name="files-icon" class="w-4 h-4" />
                  </dd>
                  <dd class="block link pl-1"><%= truncate_name(%{client_name: document.name}, @string_length) %></dd>
                </dl>
              </a>
              <div id={"options-#{document.id}"} phx-update="ignore" data-offset="0" phx-hook="Select" >
                <button title="Options" type="button" class="flex flex-shrink-0 ml-2 px-2.5 py-1.5 mt-1 bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
                  <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />
                  <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
                </button>

                <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content">
                  <button title="Deletes" type="button" phx-click="delete_document" phx-value-name={document.name} phx-value-document_id={document.id} class="flex justify-between items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                    <.icon name="trash" class="inline-block w-4 h-4 mr-2 fill-current text-red-sales-300" />
                    Delete
                  </button>
                </div>
              </div>
            </div>
            <% end %>
          </div>
          <div>
          </div>
        </div>
        <div class="flex flex-col p-4" id={"document-upload-#{@job.id}"} phx-hook="ResumeUpload">
          <form phx-change="validate" phx-submit="submit" id="upload_documents">
            <.drag_drop
            upload_entity={@uploads.documents}
            label_class="py-8"
            job_view?={true}
            />
          </form>
          <%= Enum.map(@invalid_entries, fn entry -> %>
            <.files_to_upload entry={entry} for={:job_detail} >
              <.error_action error={@invalid_entries_errors[entry.ref]} entry={entry} />
            </.files_to_upload>
          <% end) %>
          <%= Enum.map(@uploads.documents.entries, fn entry -> %>
            <.files_to_upload entry={entry} for={:job_detail} >
              <p class="btn items-center">Uploading...</p>
            </.files_to_upload>
          <% end) %>
        </div>
      </div>
      <% end %>
        <div {testid("contract")} class="grid sm:grid-cols-2 gap-5">
          <div class="flex flex-col border border-base-200 rounded-lg p-4">
            <h3 class="font-bold text-xl">Contract</h3>
            <%= cond do %>
              <% !@package -> %>
                <p class="my-2 text-base-250">You haven’t selected a package yet.</p>
                <button {testid("view-contract")} phx-click="add-package" class="mt-auto btn-primary self-end">
                  Add a package
                </button>
              <% !@proposal || (@proposal && (!@proposal.sent_to_client && is_nil(@proposal.accepted_at))) -> %>
                <p class="mt-2 text-base-250">We’ve created a contract for you to start with. If you have your own or would like to tweak the language of ours—this is the place to change. We have Business Coaching available if you need advice.</p>
                <div class="border rounded-lg px-4 py-2 mb-4 mt-auto">
                  <span class="font-bold">Selected contract:</span> <%= if @package.contract, do: @package.contract.name, else: "Picsello Default Contract" %>
                </div>
                <button type="button" phx-click="edit-contract" class="btn-primary self-end">
                  Edit or Select New
                </button>
              <% @package && @package.collected_price -> %>
                <p class="mt-2 text-base-250">During your job import, you marked this as an external document.</p>
              <% @package.contract -> %>
                <p class="mt-2 text-base-250">You sent the <%= @package.contract.name %> to your client.</p>
                <button {testid("view-contract")} type="button" phx-click="open-proposal" phx-value-action="contract" class="mt-4 btn-primary self-end">
                  View
                </button>
              <% true -> %>
            <% end %>
          </div>
          <div {testid("questionnaire")} class="flex flex-col border border-base-200 rounded-lg p-4">
            <h3 class="font-bold text-xl">Questionnaire</h3>
            <%= cond do %>
              <% !@package -> %>
                <p class="my-2 text-base-250">You haven’t selected a package yet.</p>
                <button {testid("view-contract")} type="button" phx-click="add-package" class="mt-auto btn-primary self-end">
                  Add a package
                </button>
              <% !@proposal && !@job.is_gallery_only || (@proposal && (!@proposal.sent_to_client && is_nil(@proposal.accepted_at)))-> %>
                <p class="mt-2 text-base-250">We've created a questionnaire for you to start with. You can build your own templates <.live_link to={Routes.questionnaires_index_path(@socket, :index)} class="underline text-blue-planning-300">here</.live_link>. You can come back and select your new one or add to your package templates for ease of future reuse!</p>
                <label class="flex my-4 cursor-pointer">
                  <input type="checkbox" class="w-6 h-6 mt-1 checkbox" phx-click="toggle-questionnaire" checked={@include_questionnaire} />
                  <p class="ml-3">Include questionnaire in proposal?</p>
                </label>
                <div class={classes("border rounded-lg px-4 py-2 mb-4 mt-auto", %{"opacity-50" => !@include_questionnaire})}>
                  <span class="font-bold">Selected questionnaire:</span> <%= if @package.questionnaire_template, do: @package.questionnaire_template.name, else: "Picsello Default Questionnaire" %>
                </div>
                <div class="self-end mt-auto">
                  <button {testid("view-questionnaire")} type="button" phx-click="open-questionnaire" class={classes("underline text-blue-planning-300 mr-4", %{"opacity-50 cursor-not-allowed" => !@include_questionnaire})} disabled={!@include_questionnaire}>
                    Preview
                  </button>
                  <button {testid("edit-questionnaire")} type="button" phx-click="edit-questionnaire" class="btn-primary" disabled={!@include_questionnaire}>
                    Edit or Select New
                  </button>
                </div>
              <% @package && @package.collected_price -> %>
                <p class="mt-2 text-base-250">During your job import, you marked this as an external document.</p>
              <% @proposal && @proposal.questionnaire_id -> %>
                <p class="mt-2 text-base-250">You sent the Picsello Default Questionnaire to your client.</p>
                <button {testid("view-questionnaire")} phx-click="open-proposal" phx-value-action="questionnaire" class="mt-4 btn-primary self-end">
                  View answers
                </button>
              <% true -> %>
                <p class="mt-2">Questionnaire wasn't included in the proposal</p>
            <% end %>
          </div>
        </div>
        <div class="grid md:grid-cols-3 mt-8">
          <dl class="flex flex-col">
            <dt class="font-bold">Payment schedule:</dt>
            <dd>
              <%= if !@is_schedule_valid do %>
                <.badge color={:red}>You changed a shoot date. You need to review or fix your payment schedule date.</.badge>
              <% end %>
            </dd>
            <dd>
              <%= PaymentSchedules.get_description(@job) %>
              <%= if @proposal  && (@proposal.sent_to_client || @proposal.accepted_at) do %>
                <button phx-click="open-proposal" phx-value-action="invoice" class="block link mt-2">View invoice</button>
              <% end %>
            </dd>
          </dl>
          <dl class="flex flex-col">
            <dt class="font-bold">Shoots:</dt>
            <dd>
              <%= cond do %>
                <% !@package -> %>
                  <.badge color={:red}>You haven’t selected a package yet</.badge>
                <% !Enum.all?(@shoots, &elem(&1, 1)) -> %>
                  <.badge color={:red}>Missing information in shoot details</.badge>
                <% true -> %>
                  <%= for {_, %{name: name, starts_at: starts_at}} <- @shoots do %>
                    <p><%= "#{name}—#{strftime(@current_user.time_zone, starts_at, "%m/%d/%Y")}" %></p>
                  <% end %>
              <% end %>
            </dd>
          </dl>
          <dl class="flex flex-col">
            <dt class="font-bold">Package:</dt>
            <dd>
              <%= if @package do %>
                <%= @package.name %>
              <% else %>
                <.badge color={:red}>You haven’t selected a package yet</.badge>
              <% end %>
            </dd>
          </dl>
        </div>
        <%= unless @job.is_gallery_only do %>
        <div class="flex justify-end items-center mt-8">
          <.icon_button icon="anchor" color="blue-planning-300" class="flex-shrink-0 mx-4 transition-colors px-6 py-3" id="copy-client-link" data-clipboard-text={if @proposal, do: BookingProposal.url(@proposal.id)} phx-click="copy-client-link" phx-hook="Clipboard" disabled={@disabled_copy_link}>
            <span>Copy client link</span>
            <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
              Copied!
            </div>
          </.icon_button>
          <%= if @proposal && (@proposal.sent_to_client || @proposal.accepted_at) do %>
            <button class="btn-primary" phx-click="open-proposal" phx-value-action="details">View proposal</button>
          <% else %>
            <%= render_slot(@send_proposal_button) %>
          <% end %>
        </div>
        <% end %>
      </.card>
    </.section>
    """
  end

  def history_card(assigns) do
    ~H"""
    <div {testid("history")} class="bg-base-200 p-4 px-8 rounded-lg mt-4 md:mt-0 md:ml-6 md:w-72">
      <h3 class="mb-2 text-xl font-bold"><%= @steps_title %></h3>
      <ul class="list-disc">
        <%= for item <- @steps do %>
          <li class="ml-4"><%= item %></li>
        <% end %>
      </ul>
      <h3 class="mt-4 text-xl font-bold">History</h3>
      <%= live_component PicselloWeb.JobLive.Shared.HistoryComponent, job: @job, current_user: @current_user %>
    </div>
    """
  end

  @spec shoot_details(%{
          current_user: %Picsello.Accounts.User{},
          shoot_path: fun(),
          job: %Picsello.Job{},
          shoots: list(%Picsello.Shoot{}),
          socket: %Phoenix.LiveView.Socket{}
        }) :: %Phoenix.LiveView.Rendered{}
  def shoot_details(assigns) do
    ~H"""

    """
  end

  def search_clients(assigns) do
    ~H"""
      <%= form_tag("#", [phx_change: :search, phx_submit: :submit, phx_target: @myself]) do %>
        <div class="flex flex-col justify-between items-center px-1.5 md:flex-row">
          <div class="relative flex md:w-2/3 w-full">
            <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
              <%= if Enum.any?(@search_results) || @searched_client do %>
                <span phx-click="clear-search" phx-target={@myself} class="cursor-pointer">
                  <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                </span>
              <% else %>
                <.icon name="search" class="w-4 ml-1 fill-current" />
              <% end %>
            </a>
            <input disabled={!is_nil(@selected_client) || @new_client} type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={if !is_nil(@selected_client), do: @selected_client.name, else: "#{@search_phrase}"} phx-debounce="500" phx-target={@myself} spellcheck="false" placeholder="Search clients by email or first and last names..." />
            <%= if Enum.any?(@search_results) do %>
              <div id="search_results" class="absolute top-14 w-full" phx-window-keydown="set-focus" phx-target={@myself}>
                <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white w-full overflow-auto max-h-48 h-fit">
                  <%= for {search_result, idx} <- Enum.with_index(@search_results) do %>
                    <div class={"flex items-center cursor-pointer p-2"} phx-click="pick" phx-target={@myself} phx-value-client_id={"#{search_result.id}"}>
                      <%= if search_result.id == @current_focus do %>
                        <.icon name="radio-solid" class="mr-5 w-5 h-5" />
                      <% else %>
                        <.icon name="radio" class="mr-5 w-5 h-5" />
                      <% end %>
                      <%= radio_button(:search_radio, :name, search_result.name, checked: idx == @current_focus, class: "mr-5 w-5 h-5 radio text-blue-planning-300 hidden") %>
                      <div>
                        <p><%= search_result.name %></p>
                        <p class="text-sm"><%= search_result.email %></p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <%= if @search_phrase && @search_phrase !== "" && Enum.empty?(@search_results) && is_nil(@selected_client) && is_nil(@searched_client) do %>
                <div class="absolute top-14 w-full">
                  <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 cursor-pointer shadow py-2 px-2 bg-white">
                    <p class="font-bold">No client found with that information</p>
                    <p>You'll need to add a new client</p>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
          <p class={classes("flex", %{"text-gray-400" => (!is_nil(@selected_client) || @new_client)})}>or</p>
          <button disabled={!is_nil(@selected_client) || @new_client} type="button" class="justify-right text-lg px-7 btn-primary" phx-click="new-client" phx-target={@myself}>
            Add a new client
          </button>
        </div>
      <% end %>
    """
  end

  def job_form_fields(assigns) do
    ~H"""
    <div class="px-1.5">
      <%= if @new_client do %>
        <div class="rounded-lg border border-gray-300 mt-10">
          <h3 class="rounded-t-lg bg-gray-300 px-5 py-2 text-2xl font-bold">Add a new client</h3>
          <div class="row grid grid-cols-1 px-5 py-2 sm:grid-cols-3 gap-5 mt-3">
            <%= inputs_for @form, :client, fn client_form -> %>
              <%= labeled_input client_form, :email, type: :email_input, label: "Client Email", placeholder: "email@example.com", phx_debounce: "500" %>
              <%= labeled_input client_form, :name, label: "Client Name", placeholder: "First and last name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500" %>
              <%= labeled_input client_form, :phone, type: :telephone_input, label: "Client Phone", optional: true, placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500" %>
            <% end %>
          </div>
          <div class="flex px-5 py-5 ml-auto">
            <button class="btn-secondary button rounded-lg border border-blue-planning-300 ml-auto" title="cancel" type="button" phx-click="cancel-new-client" phx-target={@myself}>
              Cancel
            </button>
          </div>
        </div>
      <% end %>
      <hr class="mt-10">
      <div class="sm:col-span-3 mt-3">
        <%= label_for @form, :type, label: "Type of Photography" %>
        <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
          <%= for job_type <- @job_types do %>
            <.job_type_option type="radio" name={input_name(@form, :type)} job_type={job_type} checked={input_value(@form, :type) == job_type} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def drag_drop(assigns) do
    assigns =
      Enum.into(assigns, %{
        label_class: "py-32",
        job_view?: nil,
        text_color: "text-black",
        item_name: "files",
        supported_types: ".PDF, .docx, .txt"
      })

    ~H"""
    <div class="dragDrop border-dashed border-2 border-blue-planning-300 rounded-lg" id="dropzone-upload" phx-hook="DragDrop" phx-drop-target={@upload_entity.ref}>
      <label class={"flex flex-col items-center justify-center w-full h-full gap-8 cursor-pointer #{@label_class}"}>
        <div class={"max-w-xs mx-auto #{@job_view? && 'flex gap-4'}"}>
          <img src={Routes.static_path(PicselloWeb.Endpoint, "/images/drag-drop-img.png")} width="76" height="76" class="mx-auto cursor-pointer opacity-75 cursor-defaul" alt="add photos icon"/>
            <div class="flex flex-col items-center justify-center dragDrop__content">
              <p class="text-center">
                <span class={"font-bold #{@text_color}"}>Drag your <%= @item_name %> or </span>
                <span class="font-bold cursor-pointer primary gray">browse</span>
                  <%= live_file_input @upload_entity, class: "dragDropInput" %>
              </p>
              <p class="text-center gray">Supports <%= @supported_types %></p>
            </div>
        </div>
      </label>
    </div>
    """
  end

  def files_to_upload(assigns) do
    assigns = Enum.into(assigns, %{myself: nil, for: nil, string_length: @string_length})

    ~H"""
      <div class={classes("uploadEntry grid grid-cols-5 pb-4 items-center", %{"px-14" => @for == :photos})}>
        <p class={classes("max-w-md overflow-hidden", %{"col-span-3" => @for == :photos, "col-span-2" => @for != :photos})}>
        <%= truncate_name(@entry, @string_length) %>
        </p>
        <div class={classes("flex photoUploadingIsFailed items-center", %{"gap-x-1 lg:gap-x-4 md:gap-x-4 grid-cols-1" => @for == :photos || @for in [:job, :job_detail], "col-span-2" => @for != :photos || @for not in [:job, :job_detail]})}>
          <%= render_slot(@inner_block) %>
        </div>
        <div class={classes("w-full ml-4 lg:ml-0 md:ml-0", %{"hidden" => @for not in [:job, :job_detail]})}>
          <div class={"sm:w-3/4 lg:w-full w-2/3 bg-green-finances-300 mt-4 mx-auto rounded-full h-1.5 mb-4 darkbg-green-finances-300 #{((!@entry.valid? || @entry.done?)) && 'invisible'}"}>
            <div class="bg-green-finances-300 font-sans h-1.5 rounded-full" style={"width: #{@entry.progress}%"}></div>
          </div>
        </div>

          <%= case @for do %>
            <% :job_detail -> %>
              <.removal_button phx-click="cancel-upload" phx-value-ref={@entry.ref} />
            <% :photos -> %>
              <.removal_button phx-target={@target} phx-click="delete_photo" phx-value-index={@index} phx-value-delete_from={@delete_from} />
            <% _ -> %>
              <div id={"file_options-#{@entry.uuid}"} data-offset-x="-60" phx-hook="Select" class="justify-self-end grid-cols-1 cursor-pointer ml-5 lg:ml-auto">
                  <button type="button" class="flex flex-shrink-0 p-2.5 bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
                    <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />
                    <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
                  </button>

                  <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content">
                    <span phx-click="cancel-upload" phx-target={@myself} phx-value-ref={@entry.ref} aria-label="remove" class="flex justify-between items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold cursor-pointer">
                      <.icon name="remove-icon" class="inline-block w-4 h-4 mr-2 fill-current text-red-sales-300"/>
                      <span class="pr-2">Delete</span>
                    </span>
                  </div>
              </div>
          <% end %>
      </div>
    """
  end

  def assign_job(
        %{assigns: %{current_user: current_user, live_action: :transactions}} = socket,
        job_id
      ) do
    job =
      current_user
      |> Job.for_user()
      |> Job.not_leads()
      |> Ecto.Query.preload([:client])
      |> Repo.get!(job_id)

    socket
    |> assign(:job, job)
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :leads}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Ecto.Query.preload([
        :client,
        :job_status,
        package: [:contract, :questionnaire_template]
      ])
      |> Repo.get!(job_id)

    if job.job_status.is_lead do
      socket |> do_assign_job(job)
    else
      push_redirect(socket, to: Routes.job_path(socket, :jobs, job_id))
    end
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :jobs}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Job.not_leads()
      |> Ecto.Query.preload([
        :client,
        :job_status,
        :payment_schedules,
        package: [:contract, :questionnaire_template]
      ])
      |> Repo.get!(job_id)

    socket |> do_assign_job(job)
  end

  def validate_payment_schedule(%{assigns: %{payment_schedules: payment_schedules}} = socket) do
    due_at_list = payment_schedules |> Enum.sort_by(& &1.id, :asc) |> Enum.map(& &1.due_at)
    updated_due_at_list = due_at_list |> Enum.sort_by(& &1, {:asc, DateTime})

    validity =
      if due_at_list == updated_due_at_list do
        dates = due_at_list |> Enum.map(&(&1 |> Timex.to_date()))
        dates == dates |> Enum.uniq()
      else
        false
      end

    socket
    |> assign(is_schedule_valid: validity)
  end

  def assign_disabled_copy_link(
        %{assigns: %{is_schedule_valid: is_schedule_valid} = assigns} = socket
      ) do
    assigns = Map.put_new(assigns, :stripe_status, nil)

    socket
    |> assign(disabled_copy_link: !is_schedule_valid || !!proposal_disabled_message(assigns))
  end

  def proposal_disabled_message(%{package: package, shoots: shoots, stripe_status: stripe_status}) do
    cond do
      !Enum.member?([:charges_enabled, :loading], stripe_status) ->
        "Set up Stripe"

      package == nil ->
        "Add a package first"

      package.shoot_count != Enum.count(shoots, &elem(&1, 1)) ->
        "Add all shoots"

      true ->
        nil
    end
  end

  def error(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        icon_class: "hidden",
        button: %{class: "hidden", title: nil, action: nil}
      })

    ~H"""
    <div class={"px-4 bg-orange-inbox-400 md:flex md:justify-between grid rounded-lg py-2 my-2 #{@class}"}>
      <div class="flex justify-start items-center">
        <.icon name="warning-orange", class={"md:w-6 md:h-6 w-10 h-10 stroke-[4px] #{@icon_class}"} />
        <div class="pl-4"><%= @message %></div>
      </div>
      <div class="flex items-center md:justify-end justify-center">
      <button type="button" class={"btn-primary intro-message #{@button.class}"} phx-click={@button.action}>
        <%= @button.title %>
      </button>
      </div>
    </div>
    """
  end

  def error_action(%{error: error, entry: entry} = assigns) do
    assigns = Map.put_new(assigns, :target, nil)

    ~H"""
    <p class="error btn items-center px-2 sm:px-1"><%= Phoenix.Naming.humanize(error) %></p>
    <p class={"retry rounded ml-2 py-1 px-2 sm:px-1 text-xs cursor-pointer #{!retryable?(error) && 'hidden'}"}
      phx-value-ref={entry.ref} phx-click="retry" phx-target={@target}>
      Retry?
    </p>
    """
  end

  def update_gallery(
        %{gallery: gallery, client: %{organization_id: organization_id}},
        shoot
      ) do
    if gallery && gallery.use_global do
      settings =
        from(gss in GSGallery,
          where: gss.organization_id == ^organization_id
        )
        |> Repo.one()

      expiration_date =
        if settings && settings.expiration_days && settings.expiration_days > 0 do
          Timex.shift(shoot.starts_at, days: settings.expiration_days) |> Timex.to_datetime()
        end

      Picsello.Galleries.update_gallery(gallery, %{expired_at: expiration_date})
    else
      nil
    end
  end

  def check_max_entries(
        %{assigns: %{uploads: %{documents: %{entries: entries} = documents}}} = socket
      ) do
    case Enum.count(entries, & &1.valid?) > documents.max_entries do
      true ->
        entries
        |> Enum.with_index()
        |> Enum.filter(&elem(&1, 0).valid?)
        |> Enum.split(documents.max_entries)
        |> then(fn {_valid, invalid} ->
          renew_uploads(socket, invalid, :max_limit_reach)
        end)

      false ->
        socket
    end
  end

  @error :duplicate
  def check_dulplication(
        %{assigns: %{uploads: %{documents: %{entries: entries}}}} = socket,
        ex_docs \\ []
      ) do
    entries
    |> Enum.with_index()
    |> Enum.group_by(fn {entry, _i} -> entry.client_name end)
    |> Enum.reduce(socket, fn {_k, [{valid, i} | invalid_entries]}, socket ->
      socket = renew_uploads(socket, invalid_entries, @error)

      if valid.client_name in ex_docs do
        renew_uploads(socket, {valid, i}, @error)
      else
        socket
      end
    end)
  end

  def renew_uploads(socket, invalid_entries, error) when is_list(invalid_entries) do
    Enum.reduce(invalid_entries, socket, fn {entry, i}, socket ->
      if entry.valid?, do: renew_uploads(socket, {entry, i}, error), else: socket
    end)
  end

  def renew_uploads(
        %{assigns: %{uploads: %{documents: %{entries: entries}}}} = socket,
        {entry, i},
        error
      ) do
    entries
    |> List.replace_at(i, %{entry | valid?: false})
    |> renew_uploads(entry, socket, [{entry.ref, error}])
  end

  def renew_uploads(entries, entry, %{assigns: %{uploads: uploads}} = socket, errs \\ []) do
    entries
    |> then(&Map.put(uploads.documents, :entries, &1))
    |> Map.update(
      :errors,
      {},
      &Enum.concat(Enum.filter(&1, fn {ref, _} -> ref != entry.ref end), errs)
    )
    |> then(&Map.put(uploads, :documents, &1))
    |> then(&assign(socket, :uploads, &1))
  end

  defdelegate path_to_url(path), to: PhotoStorage

  defp assign_documents(%{assigns: %{uploads: uploads}} = socket, entries) do
    %{documents: documents} = uploads

    uploads
    |> Map.put(:documents, Map.put(documents, :entries, entries) |> Map.put(:errors, []))
    |> then(&assign(socket, :uploads, &1))
  end

  defp ex_docs(%{job: %{documents: documents}}), do: Enum.map(documents, & &1.name)
  defp ex_docs(%{ex_documents: ex_documents}), do: Enum.map(ex_documents, & &1.client_name)

  defp search_assigns(socket) do
    socket
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:selected_client, nil)
    |> assign(:current_focus, -1)
  end

  defp search(nil, _socket), do: []

  defp search("", _socket), do: []

  defp search(search_phrase, %{assigns: %{clients: clients}}) do
    clients
    |> Enum.filter(&client_matches?(&1, search_phrase))
  end

  defp client_matches?(client, query) do
    (client.name && do_match?(client.name, query)) ||
      (client.name && do_match?(List.last(String.split(client.name)), query)) ||
      do_match?(client.email, query) ||
      (client.phone && String.contains?(client.phone, query))
  end

  defp do_match?(data, query) do
    String.starts_with?(
      String.downcase(data),
      String.downcase(query)
    )
  end

  defp assign_inbox_count(%{assigns: %{job: job}} = socket) do
    count =
      Job.by_id(job.id)
      |> ClientMessage.unread_messages()
      |> Repo.aggregate(:count)

    socket |> subscribe_inbound_messages() |> assign(:inbox_count, count)
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end

  defp complete_job_component(socket),
    do:
      socket
      |> ConfirmationComponent.open(%{
        confirm_event: "complete_job",
        confirm_label: "Yes, complete",
        confirm_class: "btn-primary",
        subtitle:
          "After you complete the job this becomes read-only. This action cannot be undone.",
        title: "Are you sure you want to complete this job?",
        icon: "warning-blue"
      })

  defp do_assign_job(socket, job) do
    galleries =
      job.id
      |> Galleries.get_galleries_by_job_id()
      |> Picsello.Repo.preload([:orders, child: [:orders]])

    child_ids = for %{child: %{id: id}} when not is_nil(id) <- galleries, do: id
    job = Map.put(job, :galleries, Enum.reject(galleries, &(&1.id in child_ids)))

    socket
    |> assign(
      job: job,
      page_title: Job.name(job),
      package: job.package
    )
    |> assign_shoots()
    |> assign_proposal()
    |> assign_inbox_count()
  end

  defp open_email_compose(%{assigns: %{job: job}} = socket),
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

  defp open_email_compose(%{assigns: %{current_user: current_user}} = socket, client_id) do
    client = Repo.get(Client, client_id)

    socket
    |> ClientMessageComponent.open(%{
      current_user: current_user,
      enable_size: true,
      enable_image: true,
      client: client
    })
    |> noreply()
  end

  defp assign_payment_schedules(socket) do
    socket
    |> then(fn %{assigns: %{job: job}} = socket ->
      payment_schedules =
        job |> Repo.preload(:payment_schedules, force: true) |> Map.get(:payment_schedules)

      socket
      |> assign(payment_schedules: payment_schedules)
      |> validate_payment_schedule()
    end)
  end

  defp second_badge(is_lead, status, label) do
    if label == "Overdue" do
      status_content(is_lead, status)
    else
      nil
    end
  end

  defp removal_button(assigns) do
    ~H"""
    <button {assigns} aria-label="remove" class="justify-self-end grid-cols-1 cursor-pointer ml-5 lg:ml-auto">
      <.icon name="remove-icon" class="w-3.5 h-3.5 ml-1 text-base-250"/>
    </button>
    """
  end

  defp retryable?(err) when err in ~w(too_large not_accepted)a, do: false
  defp retryable?(_err), do: true
end
