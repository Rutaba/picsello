defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers

  import PicselloWeb.EmailAutomationLive.Shared,
    only: [
      assign_collapsed_sections: 1,
      is_state_manually_trigger: 1,
      sort_emails: 2,
      assign_automation_pipelines: 1,
      get_pipline: 1,
      get_email_schedule_text: 6,
      get_email_name: 3
    ]

  alias Picsello.{
    EmailAutomations,
    Repo
  }

  alias PicselloWeb.ConfirmationComponent

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> is_mobile(params)
    |> default_assigns()
    |> ok()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
    |> assign_automation_pipelines()
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
        %{"pipeline_id" => pipeline_id},
        %{
          assigns: %{
            current_user: current_user,
            job_types: job_types,
            selected_job_type: selected_job_type
          }
        } = socket
      ) do
    socket
    |> open_modal(PicselloWeb.EmailAutomationLive.AddEmailComponent, %{
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
    |> open_edit_modal(params, PicselloWeb.EmailAutomationLive.EditTimeComponent)
    |> noreply()
  end

  @impl true
  def handle_event("edit-email-popup", params, socket) do
    socket
    |> open_edit_modal(params, PicselloWeb.EmailAutomationLive.EditEmailComponent)
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
      if Enum.member?(collapsed_sections, section_id) do
        Enum.filter(collapsed_sections, &(&1 != section_id))
      else
        collapsed_sections ++ [section_id]
      end

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
           "email_id" => email_id,
           "pipeline_id" => pipeline_id,
           "index" => index
         },
         module
       ) do
    socket
    |> open_modal(module, %{
      current_user: current_user,
      job_types: job_types,
      job_type: selected_job_type.jobtype,
      pipeline: get_pipline(pipeline_id),
      email_id: to_integer(email_id),
      email: EmailAutomations.get_email_by_id(to_integer(email_id)),
      index: to_integer(index)
    })
  end

  defp pipeline_section(assigns) do
    ~H"""
      <section class="mx-auto border border-base-200 rounded-lg mt-2 overflow-hidden">
        <div class="flex justify-between bg-base-200 pl-4 pr-7 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={"pipeline-#{@pipeline.id}"}>
          <div class="flex flex-row items-center">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center">
              <.icon name="play-icon" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <div class="flex flex-col">
              <span class="text-blue-planning-300 text-xl font-bold ml-3">
                <%= @pipeline.name %>
                <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap"><%= Enum.count(@pipeline.emails) %> <%= ngettext("email", "emails", Enum.count(@pipeline.emails)) %></span>
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
            <div class="px-6">
              <div class="flex md:flex-row flex-col justify-between">
                <div class="flex h-max">
                  <div class={"h-auto pt-6 md:relative #{index != last_index && "md:before:absolute md:before:border md:before:h-full md:before:border-base-200 md:before:left-1/2 md:before:z-10 md:before:z-[-1]"}"}>
                    <div testid={"email-main-icon"} class="w-8 h-8 rounded-full bg-base-200 flex items-center justify-center">
                      <%= cond do %>
                        <% is_state_manually_trigger(@pipeline.state) and index == 0 -> %> <.icon name="flag" class="w-5 h-5 text-blue-planning-300" />
                        <% email.status == :active -> %>  <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                        <% true -> %>  <.icon name="close-x" class="w-4 h-4 stroke-current stroke-3 text-blue-planning-300" />
                      <% end %>
                    </div>
                  </div>
                  <div class="ml-3 py-6">
                    <div class="text-xl font-bold">
                      <%= get_email_name(email, nil, index) %>
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
                    <.icon_button id={"email-#{email.id}"} disabled={disabled_email?(index)} class="ml-8 mr-2 px-2 py-2" title={!(index === 0) && "remove"} phx-click="delete-email" phx-value-email_id={email.id} color="red-sales-300" icon="trash"/>
                    <%= if index == 0 do %>
                      <span class={classes("text-black font-normal w-64 text-start", %{" !-left-20" => is_state_manually_trigger(@pipeline.state)})} style="white-space: normal;">
                          Can't delete first email, disable the entire sequence if you don't want it to send
                      </span>
                    <% end %>
                  </div>
                  <button phx-click="edit-time-popup" phx-value-index={index} phx-value-email_id={email.id}  phx-value-pipeline_id={@pipeline.id} class={classes("flex items-center px-2 py-1 btn-tertiary text-blue-planning-300  hover:border-blue-planning-300 mr-2 whitespace-nowrap", %{"hidden" => is_state_manually_trigger(@pipeline.state) and index == 0})}>
                    <.icon name="settings" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                    Edit time
                  </button>
                  <button phx-click="edit-email-popup" phx-value-index={index} phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75 whitespace-nowrap" >
                    <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
                    Edit email
                  </button>
                </div>
              </div>
              <hr class="md:ml-8 ml-6" />
            </div>
          <% end %>
          <div class="flex flex-row justify-between pr-6 pl-8 sm:pl-16 py-6">
            <div class="flex items-center">
              <button phx-click="add-email-popup" phx-value-pipeline_id={@pipeline.id} data-popover-target="popover-default" type="button" class="flex items-center px-2 py-1 btn-tertiary hover:border-blue-planning-300" >
                <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                    Add email
              </button>
            </div>
            <%= if !is_state_manually_trigger(@pipeline.state) and @subcategory_slug != "payment_reminder_emails" do %>
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
end
