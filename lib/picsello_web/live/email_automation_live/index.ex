defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.EmailAutomationLive.Shared, only: [assign_automation_pipelines: 1]

  alias Picsello.{
    EmailAutomation,
    Repo,
    Marketing
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> assign(:collapsed_sections, [])
    |> default_assigns()
    |> ok()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
    # |> assign(:selected_pipeline, "")
    |> assign_automation_pipelines()
  end

  defp assign_job_types(%{assigns: %{current_user: current_user}} = socket) do
    current_user =
      current_user
      |> Repo.preload([organization: [organization_job_types: :jobtype]], force: true)

    job_types =
      current_user.organization.organization_job_types
      |> Enum.sort_by(& &1.jobtype.position)

    selected_job_type = job_types |> List.first()

    socket
    |> assign(:current_user, current_user)
    |> assign(:job_types, job_types)
    |> assign(:selected_job_type, selected_job_type)
  end

  # category
  #   subcategory
  #     pipeline
  #       email
  #       email
  #     pipeline
  #       email
  #       email
  #   subcategory

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
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-email-popup",
        %{"pipeline_id" => pipeline_id},
        %{assigns: %{current_user: current_user, selected_job_type: selected_job_type}} = socket
      ) do
    socket
    |> open_modal(PicselloWeb.EmailAutomationLive.AddEmailComponent, %{
      current_user: current_user,
      job_type: selected_job_type,
      pipeline: get_pipline(pipeline_id)
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
        %{"email-automation-setting-id" => setting_id},
        %{assigns: %{selected_job_type: selected_job_type}} = socket
      ) do
    email_delete =
      to_integer(setting_id)
      |> EmailAutomation.delete_email(selected_job_type.id)

    case email_delete do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Successfully created")

      _ ->
        socket
        |> put_flash(:error, "Failed to delete email")
    end
    |> assign_automation_pipelines()
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
        socket
      ) do
    message = if active == "true", do: "disabled", else: "enabled"

    case EmailAutomation.update_pipeline_and_settings_status(id, active) do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Pipeline successfully #{message}")

      _ ->
        socket
        |> put_flash(:error, "Failed to update pipeline s tatus")
    end
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_info({:update_automation, %{message: message}}, socket) do
    socket
    |> assign_automation_pipelines()
    |> put_flash(:success, message)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:load_template_preview, component, body_html},
        %{assigns: %{current_user: current_user, modal_pid: modal_pid}} = socket
      ) do
    template_preview = Marketing.template_preview(current_user, body_html)

    send_update(
      modal_pid,
      component,
      id: component,
      template_preview: template_preview
    )

    socket
    |> noreply()
  end

  defp get_pipline(pipeline_id) do
    to_integer(pipeline_id)
    |> EmailAutomation.get_pipeline_by_id()
    |> Repo.preload([:email_automation_category, :email_automation_sub_category])
  end

  defp open_edit_modal(
         %{assigns: %{current_user: current_user, selected_job_type: selected_job_type}} = socket,
         %{
           "email_id" => email_id,
           "email_automation_setting_id" => email_automation_setting_id,
           "pipeline_id" => pipeline_id
         },
         module
       ) do
    socket
    |> open_modal(module, %{
      current_user: current_user,
      job_type: selected_job_type,
      pipeline: get_pipline(pipeline_id),
      email_automation_setting_id: to_integer(email_automation_setting_id),
      email:
        EmailAutomation.get_email_by_id(to_integer(email_id))
        |> Repo.preload(:email_automation_types)
    })
  end

  def pipeline_section(assigns) do
    ~H"""
      <section class="mx-auto border border-base-200 rounded-lg mt-2 overflow-hidden">
        <div class="flex justify-between bg-base-200 pl-4 pr-7 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={"pipeline-#{@pipeline.id}"}>
          <div class="flex-row flex items-center">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center">
              <.icon name="play-icon" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <span class="text-blue-planning-300 text-xl font-bold ml-3">
              <%= @pipeline.name %>
              <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap"><%= Enum.count(@pipeline.emails)%> emails</span>
            </span>
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
          <%= for {email, index} <- Enum.with_index(@pipeline.emails) do %>
            <div class="px-6 pt-6">
              <div class="flex md:flex-row flex-col justify-between">
                <div class="flex">
                  <div class="w-8 h-8 rounded-full bg-base-200 flex items-center justify-center mr-3">
                    <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                  </div>
                  <div>
                    <div class="text-xl font-bold">
                      <%= email.name %>
                    </div>
                    <div class="flex flex-row items-center text-base-250">
                      <.icon name="play-icon" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                      <span>Send email immediately</span>
                    </div>
                  </div>
                </div>

                <div class="flex items-center md:mt-0 ml-auto mt-4">
                  <div class="custom-tooltip">
                    <.icon_button id={"email-#{email.id}"} disabled={disabled_email?(index)} class="ml-8 mr-2 px-2 py-2" title="remove" phx-click="delete-email" phx-value-email_automation_setting_id={email.email_automation_setting.id} color="red-sales-300" icon="trash"/>
                    <%= if index == 0 do %>
                      <span class="text-black font-normal w-64 text-start" style="white-space: normal;">
                          Can't delete first email; disable the entire sequence if you don't want it to send
                      </span>
                    <% end %>
                  </div>
                  <button phx-click="edit-time-popup" phx-value-email_id={email.id} phx-value-email_automation_setting_id={email.email_automation_setting.id} phx-value-pipeline_id={@pipeline.id} class="flex items-center px-2 py-1 btn-tertiary text-blue-planning-300  hover:border-blue-planning-300 mr-2 whitespace-nowrap">
                    <.icon name="settings" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                    Edit time
                  </button>
                  <button phx-click="edit-email-popup" phx-value-email_id={email.id} phx-value-email_automation_setting_id={email.email_automation_setting.id} phx-value-pipeline_id={@pipeline.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75 whitespace-nowrap" >
                    <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
                    Edit email
                  </button>
                </div>
              </div>
              <hr class="mt-6 md:ml-8 ml-6" />
            </div>
          <% end %>
          <div class="flex flex-row justify-between pr-6 pl-8 sm:pl-16 py-6">
            <div class="flex items-center">
              <button phx-click="add-email-popup" phx-value-pipeline_id={@pipeline.id} data-popover-target="popover-default" type="button" class="flex items-center px-2 py-1 btn-tertiary hover:border-blue-planning-300" >
                <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                    Add email
              </button>
            </div>

            <div class="flex flex-row">
              <.form :let={_} for={%{}} as={:toggle} phx-click="toggle" phx-value-pipeline_id={@pipeline.id} phx-value-active={is_pipeline_active?(@pipeline.status) |> to_string}>
              <label class="flex">
                <input type="checkbox" class="peer hidden" checked={is_pipeline_active?(@pipeline.status)}/>
                <div class="hidden peer-checked:flex cursor-pointer">
                  <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                    <div class="rounded-full h-5 w-5 bg-base-100"></div>
                  </div>
                  Enable automation
                </div>
                <div class="flex peer-checked:hidden cursor-pointer">
                  <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                    <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                  </div>
                  Disable automation
                </div>
              </label>
              </.form>
            </div>
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
