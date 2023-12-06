defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  import PicselloWeb.EmailAutomationLive.Shared,
    only: [
      assign_collapsed_sections: 1,
      is_state_manually_trigger: 1,
      sort_emails: 2,
      assign_automation_pipelines: 1,
      get_pipline: 1,
      get_email_schedule_text: 6,
      get_email_name: 4
    ]

  import PicselloWeb.LiveHelpers

  alias Picsello.{EmailAutomations, Packages, Repo}

  alias PicselloWeb.{
    ConfirmationComponent,
    EmailAutomationLive.EditTimeComponent,
    EmailAutomationLive.EditEmailComponent,
    EmailAutomationLive.AddEmailComponent
  }

  @always_enabled_states ~w(digitals_ready_download order_confirmation_digital_physical thanks_booking thanks_job pays_retainer_offline pays_retainer)
  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> assign(:always_enabled_states, @always_enabled_states)
    |> is_mobile(params)
    |> default_assigns()
    |> ok()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
    |> assign_automation_pipelines()
    |> assign_global_automation_settings()
    |> assign_collapsed_sections()
  end

  defp assign_job_types(%{assigns: %{current_user: current_user}} = socket) do
    current_user =
      current_user
      |> Repo.preload([organization: [organization_job_types: :jobtype]], force: true)

    job_types =
      current_user.organization.organization_job_types
      |> Picsello.Profiles.get_active_organization_job_types()

    selected_job_type = job_types |> List.first()

    socket
    |> assign(:current_user, current_user)
    |> assign(:job_types, job_types)
    |> assign(:selected_job_type, selected_job_type)
  end

  defp assign_global_automation_settings(%{assigns: %{current_user: current_user}} = socket) do
    user = Packages.get_current_user(current_user.id)

    global_automation_enabled? = user.organization.global_automation_enabled

    socket
    |> assign(:global_automation_enabled, global_automation_enabled?)
  end

  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket
    |> assign(:is_mobile, !is_mobile)
    |> noreply()
  end

  @impl true
  def handle_event(
        "assign_templates_by_type",
        %{"id" => id},
        %{assigns: %{job_types: job_types}} = socket
      ) do
    id = to_integer(id)

    selected_job_type = job_types |> Enum.filter(fn x -> x.id == id end) |> List.first()

    socket
    |> assign(:selected_job_type, selected_job_type)
    |> assign(is_mobile: false)
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-email-popup",
        %{"pipeline-id" => pipeline_id},
        %{
          assigns: %{
            current_user: current_user,
            job_types: job_types,
            selected_job_type: selected_job_type
          }
        } = socket
      ) do
    socket
    |> open_modal(AddEmailComponent, %{
      current_user: current_user,
      job_type: selected_job_type.jobtype,
      pipeline: get_pipline(pipeline_id),
      job_types: job_types
    })
    |> noreply()
  end

  @impl true
  def handle_event("edit-time-popup", params, socket) do
    socket
    |> open_edit_modal(params, EditTimeComponent)
    |> noreply()
  end

  @impl true
  def handle_event("edit-email-popup", params, socket) do
    socket
    |> open_edit_modal(params, EditEmailComponent)
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-email",
        %{"email-id" => email_id},
        socket
      ) do
    email_delete = to_integer(email_id)

    socket
    |> assign(:email_id, email_delete)
    |> ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "confirm-delete-email",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      subtitle:
        "Do you wish to permanently delete this email template. It will remove the email from the current email automation pipeline sub-category!",
      title: "Are you sure you want to delete this email template?"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-section",
        %{"section_id" => section_id},
        %{assigns: %{collapsed_sections: collapsed_sections}} = socket
      ) do
    collapsed_sections =
      if Enum.member?(collapsed_sections, section_id),
        do: Enum.filter(collapsed_sections, &(&1 != section_id)),
        else: collapsed_sections ++ [section_id]

    socket
    |> assign(:collapsed_sections, collapsed_sections)
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle",
        %{"pipeline-id" => id, "active" => active},
        %{assigns: %{selected_job_type: _selected_job_type}} = socket
      ) do
    message = if active == "true", do: "disabled", else: "enabled"

    case EmailAutomations.update_pipeline_and_settings_status(id, active) do
      {_count, nil} ->
        socket
        |> put_flash(:success, "Email template successfully #{message}")

      _error ->
        socket
        |> put_flash(:error, "Failed to update email template status")
    end
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_global",
        %{"active" => active},
        socket
      ) do
    message = if active == "true", do: "disable", else: "enable"

    socket
    |> ConfirmationComponent.open(%{
      title: "Are you sure you want to #{message} all the automation",
      subtitle: "Are you sure you want to #{message} all the automation",
      confirm_event: "confirm-toggle-global-#{active}",
      close_event: "cancel_toggle",
      confirm_label: "Yes",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> assign_global_automation_settings()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:close_event, "cancel_toggle"},
        socket
      ) do
    socket
    |> close_modal()
    |> assign_global_automation_settings()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "confirm-toggle-global-" <> active},
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    status = if active == "true", do: "disabled", else: "enabled"

    case EmailAutomations.update_globally_automations_emails(organization.id, status) do
      {:ok, _} ->
        socket
        |> assign_global_automation_settings()
        |> put_flash(
          :success,
          "Email template successfully #{status}"
        )

      _error ->
        socket
        |> put_flash(:success, "Failed to process template enabling/disabling")
    end
    |> close_modal()
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "confirm-delete-email"},
        %{assigns: %{email_id: email_id}} = socket
      ) do
    case EmailAutomations.delete_email(email_id) do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Email template successfully deleted")

      _ ->
        socket
        |> put_flash(:success, "Failed to delete the email template")
    end
    |> close_modal()
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.EmailAutomationLive.Shared

  defp open_edit_modal(
         %{
           assigns: %{
             job_types: job_types,
             current_user: current_user,
             selected_job_type: selected_job_type
           }
         } = socket,
         %{
           "email-id" => email_id,
           "pipeline-id" => pipeline_id,
           "index" => index
         } = params,
         module
       ) do
    pipline = get_pipline(pipeline_id)

    socket
    |> open_modal(module, %{
      current_user: current_user,
      job_types: job_types,
      job_type: selected_job_type.jobtype,
      pipeline: pipline,
      show_enable_setting?:
        pipline.state
        |> to_string()
        |> show_enable_setting?(params["subcategory-slug"]),
      email_id: to_integer(email_id),
      email: EmailAutomations.get_email_by_id(to_integer(email_id)),
      index: to_integer(index)
    })
  end

  defp show_enable_setting?(state, subcategory_slug) do
    state not in @always_enabled_states and !is_state_manually_trigger(state) and
      subcategory_slug != "payment_reminder_emails"
  end

  defp pipeline_section(assigns) do
    ~H"""
      <section class="mx-auto border border-base-200 rounded-lg mt-2 overflow-hidden" testid={@pipeline.state}>
        <div class="flex justify-between bg-base-200 pl-4 pr-7 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={"pipeline-#{@pipeline.id}"}>
          <div class="flex flex-row items-center">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center">
              <%= if is_state_manually_trigger(@pipeline.state) do %>
                <.icon name="paper-airplane" class="w-5 h-5 text-blue-planning-300" />
              <% else %>
                <.icon name="play-icon" class="w-5 h-5 text-blue-planning-300" />
              <% end %>
            </div>
            <div class="flex flex-col">
              <span class="text-blue-planning-300 text-xl font-bold ml-3">
                <%= @pipeline.name %>
                <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap"><%= Enum.count(@pipeline.emails) %> <%= ngettext("email", "emails", Enum.count(@pipeline.emails)) %></span>
                <%= if is_state_manually_trigger(@pipeline.state) do %>
                  <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap">Manual Trigger</span>
                <% end %>
              </span>
              <div class="text-base-250 text-sm ml-3">
                <%= @pipeline.description %>
              </div>
            </div>
          </div>

          <div class="flex">
            <%= if !Enum.member?(@collapsed_sections, "pipeline-#{@pipeline.id}") do %>
              <.icon name="down" class="text-blue-planning-300 w-6 h-6 stroke-current stroke-3" />
            <% else %>
              <.icon name="up" class="text-blue-planning-300 w-6 h-6 stroke-current stroke-3" />
            <% end %>
          </div>
        </div>

        <%= if Enum.member?(@collapsed_sections, "pipeline-#{@pipeline.id}") do %>
          <% emails = sort_emails(@pipeline.emails, @pipeline.state) %>
          <%= for {email, index} <- Enum.with_index(emails) do %>
            <% last_index = Enum.count(emails) - 1 %>
            <div class="px-6" testid="email">
              <div class="flex md:flex-row flex-col justify-between">
                <div class="flex h-max">
                  <div class={"h-auto pt-6 md:relative #{index != last_index && "md:before:absolute md:before:border md:before:h-full md:before:border-base-200 md:before:left-1/2 md:before:z-10 md:before:z-[-1]"}"}>
                    <div testid={"email-main-icon"} class="w-8 h-8 rounded-full bg-base-200 flex items-center justify-center">
                      <%= cond do %>
                        <% is_state_manually_trigger(@pipeline.state) and index == 0 -> %> <.icon name="paper-airplane" class="w-5 h-5 text-blue-planning-300" />
                        <% email.status == :active -> %>  <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                        <% true -> %>  <.icon name="close-x" class="w-4 h-4 stroke-current stroke-3 text-blue-planning-300" />
                      <% end %>
                    </div>
                  </div>
                  <div class="ml-3 py-6">
                    <div class="text-xl font-bold">
                      <%= get_email_name(email, nil, index, @pipeline.state) %>
                      <%= if email.status == :disabled do %>
                        <span class="ml-2 rounded-md bg-red-sales-100 text-red-sales-300 px-2 text-sm font-bold whitespace-nowrap">Disabled</span>
                      <% end %>
                    </div>
                    <div class="flex flex-row items-center text-base-250">
                      <div clas="w-4 h-4">
                        <.icon name="play-icon" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                      </div>
                      <span class="text-sm"><%= get_email_schedule_text(email.total_hours, @pipeline.state, emails, index, nil, nil) %> </span>
                    </div>
                  </div>
                </div>

                <div class="flex items-center md:mt-0 ml-auto md:pb-0 pb-6 md:pt-6">
                  <div class="custom-tooltip">
                    <%= unless emails_send_immediately_states?(@subcategory_slug, @pipeline.state) do %>
                      <.icon_button id={"email-#{email.id}"} disabled={disabled_email?(index)} class="ml-8 mr-2 px-2 py-2" title={!(index === 0) && "remove"} phx-click="delete-email" phx-value-email_id={email.id} color="red-sales-300" icon="trash"/>
                    <% end %>
                    <%= if index == 0 do %>
                      <span class={classes("text-black font-normal w-64 text-start", %{" !-left-20" => is_state_manually_trigger(@pipeline.state)})} style="white-space: normal;">
                          Can't delete first email, disable the entire sequence if you don't want it to send
                      </span>
                    <% end %>
                  </div>
                  <%= unless emails_send_immediately_states?(@subcategory_slug, @pipeline.state) do %>
                    <.button_simple class={classes("flex items-center px-2 py-1 btn-tertiary text-blue-planning-300 hover:border-blue-planning-300 mr-2 whitespace-nowrap", %{"hidden" => is_state_manually_trigger(@pipeline.state) and index == 0})} phx-click="edit-time-popup" phx-value-index={index} phx-value-subcategory_slug={@subcategory_slug} phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id} icon_class="inline-block w-4 h-4 mr-3" color="blue-planning-300" icon="settings">Edit time</.button_simple>
                  <% end %>
                  <.button_simple class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75 whitespace-nowrap" phx-click="edit-email-popup" phx-value-index={index} phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id} icon_class="inline-block w-4 h-4 mr-3" color="white" icon="pencil">Edit email</.button_simple>
                </div>
              </div>
              <hr class="md:ml-8 ml-6" />
            </div>
          <% end %>
          <div class="flex flex-row justify-between pr-6 pl-8 sm:pl-16 py-6">
            <div class="flex items-center">
              <%= unless emails_send_immediately_states?(@subcategory_slug, @pipeline.state) do %>
                <.button_simple class="flex items-center px-2 py-1 btn-tertiary hover:border-blue-planning-300" phx-click="add-email-popup" phx-value-pipeline_id={@pipeline.id} data-popover-target="popover-default" icon_class="inline-block w-4 h-4 mr-3" color="blue-planning-300" icon="plus">Add email</.button_simple>
              <% end %>
            </div>
            <%= if show_enable_setting?(@pipeline.state, @subcategory_slug) do %>
              <div class="flex flex-row">
                <.form :let={_} for={%{}} as={:toggle} phx-click="toggle" phx-value-pipeline_id={@pipeline.id} phx-value-active={is_pipeline_active?(@pipeline.status) |> to_string}>
                <label class="flex">
                  <input type="checkbox" class="peer hidden" checked={is_pipeline_active?(@pipeline.status)}/>
                  <div testid={"enable-#{@pipeline.id}"} class="hidden peer-checked:flex cursor-pointer">
                    <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                      <div class="rounded-full h-5 w-5 bg-base-100"></div>
                    </div>
                    Enable Sequence
                  </div>
                  <div testid={"disable-#{@pipeline.id}"} class="flex peer-checked:hidden cursor-pointer">
                    <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                      <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                    </div>
                    Disable Sequence
                  </div>
                </label>
                </.form>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>
    """
  end

  defp is_pipeline_active?("active"), do: true
  defp is_pipeline_active?(_), do: false

  defp disabled_email?(0), do: true
  defp disabled_email?(_), do: false

  defp emails_send_immediately_states?(_, state)
       when state in ["client_contact", "abandoned_emails"],
       do: true

  defp emails_send_immediately_states?(slug, _state)
       when slug in [
              "order_confirmation_emails",
              "booking_response_emails",
              "payment_reminder_emails"
            ],
       do: true

  defp emails_send_immediately_states?(_slug, _state), do: false
end
