defmodule PicselloWeb.EmailAutomationLive.EditTimeComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.EmailAutomation.{EmailAutomationSetting, EmailAutomationType}
  alias Ecto.Changeset
  alias Picsello.{Repo, EmailPresets, Jobs, JobType, GlobalSettings.Gallery, EmailPresets.EmailPreset}

  @impl true
  def update(%{
    current_user: current_user,
    job_type: job_type,
    pipeline: %{email_automation_category: %{type: type}}
    } = assigns, socket) do
    IO.inspect assigns
    job_types = Jobs.get_job_types_with_label(current_user.organization_id)
    |> Enum.map(&Map.put(&1, :selected, &1.id == job_type.id))

    email_presets = EmailPresets.email_automation_presets(type)

    # IO.inspect email_presets
    socket
    |> assign(assigns)
    |> assign(job_types: job_types)
    |> assign(email_presets: email_presets)
    |> assign(email_preset: List.first(email_presets))
    |> assign_changeset(%{})
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  @impl true
  def update(%{options: options}, socket) do
    socket
    |> assign(job_types: options)
    |> ok()
  end

  defp prepare_params(email_preset) do
    %{
      "total_days" => 0,
      "email_preset" => prepare_email_preset_params(email_preset)
    }
  end

  defp prepare_email_preset_params(email_preset) do
    email_preset
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end

  defp step_valid?(assigns),
  do:
    Enum.all?(
      [
        assigns.changeset
      ],
      & &1.valid?
    )

  @impl true
  def handle_event("validate", %{"email_preset" => params}, %{assigns: %{email_preset: email_preset, email_presets: email_presets}} = socket) do
    template_id = Map.get(params, "template_id", "1") |> to_integer()
    new_email_preset = Enum.filter(email_presets, & &1.id == template_id) |> List.first()

    params = if email_preset.id == template_id, do: params, else: nil

    socket
    |> assign(email_preset: new_email_preset)
    |> email_preset_changeset(new_email_preset, params)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"email_automation_setting" => params}, socket) do
    socket
    |> assign_changeset(maybe_normalize_params(params))
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "timing"} = params, %{assigns: %{email_preset: email_preset} = assigns} = socket) do
    if Map.get(assigns, :email_preset_changeset, nil) do
      socket
    else
      socket
      |> email_preset_changeset(email_preset)
    end
    |> noreply()
  end

  defp email_preset_changeset(socket, email_preset, params \\ nil) do
    email_preset_changeset = build_changeset(email_preset, params)
    body_template = current(email_preset_changeset) |> Map.get(:body_template)

    if params do
      socket
    else
      socket
      |> push_event("quill:update", %{"html" => body_template})
    end
    |> assign(email_preset_changeset: email_preset_changeset)
  end

  defp build_changeset(email_preset, params) do
    if params do
      params
    else
      email_preset
      |> Map.put(:template_id, email_preset.id)
      |> prepare_email_preset_params()
    end
    |> EmailPreset.changeset()
  end

  @impl true
  def handle_event("submit", %{"step" => "preview_email"}, %{assigns: assigns} = socket) do
    socket
    |> save()
    |> close_modal()
    |> noreply()
  end

  defp save(%{
    assigns: %{
      changeset: changeset,
      email_preset_changeset: email_preset_changeset,
      job_types: job_types,
      pipeline: pipeline
      }} = socket) do
    selected_job_types = Enum.filter(job_types, & &1.selected)
    IO.inspect selected_job_types
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:email_automation_setting, changeset)
    |> Ecto.Multi.insert(:email_preset, fn %{email_automation_setting: %{id: setting_id}} ->
      email_preset_changeset
      |> Ecto.Changeset.put_change(:email_automation_setting_id, setting_id)
    end)
    |> Ecto.Multi.insert_all(
      :email_automation_types,
      EmailAutomationType,
      fn %{email_automation_setting: %{id: setting_id}, email_preset: %{id: email_id}} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        selected_job_types
        |> Enum.map(&%{
          organization_job_id: &1.id,
          email_automation_setting_id: setting_id,
          email_preset_id: email_id,
          inserted_at: now,
          updated_at: now
        })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{email_automation_setting: email_automation_setting, email_preset: email_preset}} ->
        send(self(), {:update_automation, %{email_automation_setting: email_automation_setting, email_preset: email_preset}})
      _ -> :error
    end

    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.close_x />
        <h1 class="mt-2 mb-4 text-3xl">
          <span class="font-bold">Edit Email Automation Settings</span>
        </h1>

        <.form for={@changeset} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-timing"}>
          <input type="hidden" />

          <div class="rounded-lg border-base-200 border">
            <div class="bg-base-200 p-4 flex rounded-t-lg">
              <div class="flex flex-row items-center">
                <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
                  <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                </div>
                <span class="text-blue-planning-300 text-lg"><b>Send email:</b> Shoot Prep # x</span>
              </div>
              <div class="flex ml-auto items-center">
                <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
                  <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
                </div>
                <span>Job Automation</span>
              </div>
            </div>

            <% f = to_form(@changeset) %>
            <%= hidden_input f, :email_automation_pipeline_id %>
            <%= hidden_input f, :organization_id %>
            <div class="flex md:flex-row flex-col w-full md:px-14 px-6 py-6">

              <div class="flex flex-col w-full md:pr-6">
                <b>Email timing</b>
                <span class="text-base-250">Choose when you’d like your email to send</span>
                <div class="flex gap-4 flex-col my-4">
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :immediately, true, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Send immediately when event happens</p>
                  </label>
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :immediately, false, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Send at a certain time</p>
                  </label>
                  <%= unless input_value(f, :immediately) do %>
                    <div class="flex flex-col ml-8">
                      <div class="flex w-full my-2">
                        <div class="w-1/5">
                          <%= input f, :count, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer w-full" %>
                        </div>
                          <div class="ml-2 w-3/5">
                          <%= select f, :calendar, ["Day", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                        </div>
                        <div class="ml-2 w-3/5">
                          <%= select f, :sign, [Before: "-", After: "+"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                        </div>
                      </div>
                      <%= if message = @changeset.errors[:count] do %>
                        <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <b>Email Status</b>
                <span class="text-base-250">Choose whether or not this email should send</span>

                <div>
                  <label class="flex pt-4">
                    <%= checkbox f, :status, class: "peer hidden", checked: Changeset.get_field(@changeset, :status) == :active %>
                    <div class="hidden peer-checked:flex cursor-pointer">
                      <div class="rounded-full bg-blue-planning-300 border border-base-100 w-14 p-1 flex justify-end mr-4">
                        <div class="rounded-full h-5 w-5 bg-base-100"></div>
                      </div>
                      Email enabled
                    </div>
                    <div class="flex peer-checked:hidden cursor-pointer">
                      <div class="rounded-full w-14 p-1 flex mr-4 border border-blue-planning-300">
                        <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                      </div>
                      Email disabled
                    </div>
                  </label>
                </div>
              </div>

              <hr class="my-4 md:hidden flex" />

              <div class="flex flex-col w-full md:pl-6 md:border-l md:border-base-200">
                <b>Email Automation sequence conditions</b>
                <span class="text-base-250">Choose to run automatically or when conditions are met</span>
                <div class="flex gap-4 flex-col my-4">
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :normally, true, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Run automation normally</p>
                  </label>
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :normally, false, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Run automation only if:</p>
                  </label>
                  <%= unless input_value(f, :normally) do %>
                    <div class="flex my-2 ml-8">
                      <%= select f, :condition, ["Client doesn’t respond by email send time", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <.footer class="pt-10">
            <button class="btn-primary" title="Save" disabled={!step_valid?(assigns)} type="submit" phx-disable-with="Save">
              Save
            </button>
            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Close
            </button>
          </.footer>
        </.form>
      </div>
    """
  end

  defp assign_changeset(%{assigns: %{job_types: job_types, current_user: current_user, pipeline: pipeline} = assigns} = socket, params, action \\ nil) do
    automation_params =
      params
      |> Map.merge(%{
        "email_automation_pipeline_id" => pipeline.id,
        "organization_id" => current_user.organization_id
      })

    changeset = EmailAutomationSetting.changeset(automation_params) |> Map.put(:action, action)

    # IO.inspect email_preset_changeset
    # IO.inspect changeset |> current()

    assign(socket,
      changeset: changeset,
      # email_preset_changeset: email_preset_changeset
      # package_pricing: package_pricing_changeset,
      # download_changeset: download_changeset
    )
  end

  defp maybe_normalize_params(params) do
    {_, params} = get_and_update_in(
      params,
      ["status"],
      &{&1, if(&1 == "true", do: :active, else: :disabled)}
      )

    params
  end

end
