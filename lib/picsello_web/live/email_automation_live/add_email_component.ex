defmodule PicselloWeb.EmailAutomationLive.AddEmailComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.Shared.MultiSelect

  alias Picsello.{Repo, EmailPresets, EmailPresets.EmailPreset}
  alias PicselloWeb.EmailAutomationLive.Shared
  alias Ecto.Changeset

  @steps [:timing, :edit_email, :preview_email]

  @impl true
  def update(
        %{
          job_type: job_type,
          pipeline: %{email_automation_category: %{type: type}}
        } = assigns,
        socket
      ) do
    job_types =
      Picsello.JobType.all()
      |> Enum.map(&%{id: &1, label: &1, selected: &1 == job_type.name})

    email_presets = EmailPresets.email_automation_presets(type)

    socket
    |> assign(assigns)
    |> assign(job_types: job_types)
    |> assign(email_presets: email_presets)
    |> assign(email_preset: List.first(email_presets))
    |> assign(steps: @steps)
    |> assign(step: :timing)
    |> assign_changeset(nil)
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  @impl true
  def update(%{options: options}, socket) do
    socket
    |> assign(job_types: options)
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(steps: @steps)
    |> assign(step: :preview_email)
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  defp step_valid?(assigns),
    do:
      Enum.all?(
        [
          assigns.email_preset_changeset
        ],
        & &1.valid?
      )
      |> Shared.validate?(assigns.job_types)

  @impl true
  def handle_event("back", _, %{assigns: %{step: step, steps: steps}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"email_preset" => params},
        %{
          assigns: %{
            email_preset: email_preset,
            email_presets: email_presets,
            current_user: current_user,
            pipeline: pipeline
          }
        } = socket
      ) do
    template_id = Map.get(params, "template_id", "1") |> to_integer()

    new_email_preset =
      Enum.filter(email_presets, &(&1.id == template_id))
      |> List.first()
      |> Map.merge(%{
        email_automation_pipeline_id: pipeline.id,
        organization_id: current_user.organization_id
      })

    params = if email_preset.id == template_id, do: params, else: nil

    socket
    |> assign(email_preset: new_email_preset)
    |> Shared.email_preset_changeset(new_email_preset, maybe_normalize_params(params))
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"email_automation_setting" => params}, socket) do
    socket
    |> assign_changeset(maybe_normalize_params(params))
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "timing"},
        %{assigns: %{email_preset: email_preset} = assigns} = socket
      ) do
    if Map.get(assigns, :email_preset_changeset, nil) do
      socket
    else
      socket
      |> Shared.email_preset_changeset(email_preset)
    end
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "edit_email"},
        %{assigns: %{email_preset_changeset: changeset} = assigns} = socket
      ) do
    body_html = Ecto.Changeset.get_field(changeset, :body_template)
    Process.send_after(self(), {:load_template_preview, __MODULE__, body_html}, 50)

    socket
    |> assign(:template_preview, :loading)
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "preview_email"}, socket) do
    socket
    |> save()
    |> close_modal()
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.close_x />
        <.steps step={@step} steps={@steps} target={@myself} />

        <h1 class="mt-2 mb-4 text-3xl">
          <span class="font-bold">Add <%= String.capitalize(@job_type.name)%> Email Step:</span>
          <%= case @step do %>
            <% :timing -> %> Timing
            <% :edit_email -> %> Edit Email
            <% :preview_email -> %> Preview Email
          <% end %>
        </h1>

        <.form for={@email_preset_changeset} :let={f} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
        <%= hidden_input f, :email_automation_pipeline_id %>
        <%= hidden_input f, :organization_id %>
        <%= hidden_input f, :type, value: @pipeline.email_automation_category.type %>
        <%= hidden_input f, :name %>
        <%= hidden_input f, :position %>

          <input type="hidden" name="step" value={@step} />

          <.step name={@step} f={f} {assigns} />

          <.footer class="pt-10">
            <div class="mr-auto md:hidden flex w-full">
              <.multi_select
                id="job_types_mobile"
                select_class="w-full"
                hide_tags={true}
                placeholder="Add to:"
                search_on={false}
                form="job_type"
                on_change={fn options -> send_update(__MODULE__, id: __MODULE__, options: options) end}
                options={@job_types}
              />
            </div>
            <.step_buttons step={@step} form={f} is_valid={step_valid?(assigns)} myself={@myself} />

            <%= if step_number(@step, @steps) == 1 do %>
              <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
                Close
              </button>
            <% else %>
              <button class="btn-secondary" title="back" type="button" phx-click="back" phx-target={@myself}>
                Go back
              </button>
            <% end %>

            <div class="mr-auto hidden md:flex">
              <.multi_select
                id="job_types"
                select_class="w-52"
                hide_tags={true}
                placeholder="Add to:"
                search_on={false}
                form="job_type"
                on_change={fn options -> send_update(__MODULE__, id: __MODULE__, options: options) end}
                options={@job_types}
              />
            </div>
          </.footer>
        </.form>
      </div>
    """
  end

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defp next_step(%{step: step, steps: steps}) do
    Enum.at(steps, Enum.find_index(steps, &(&1 == step)) + 1)
  end

  def step_buttons(%{step: step} = assigns) when step in [:timing, :edit_email] do
    ~H"""
    <button class="btn-primary" title="Next" disabled={!@is_valid} type="submit" phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{step: :preview_email} = assigns) do
    ~H"""
    <button class="btn-primary" title="Save" disabled={!@is_valid} type="submit" phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{step: :timing} = assigns) do
    ~H"""
      <div class="rounded-lg border-base-200 border">
        <div class="bg-base-200 p-4 flex rounded-t-lg">
          <div class="flex flex-row items-center">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
              <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <span class="text-blue-planning-300 text-lg"><b>Send email:</b> <%= @pipeline.name %></span>
          </div>
          <div class="flex ml-auto items-center">
            <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
              <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
            </div>
            <span>Job Automation</span>
          </div>
        </div>

        <% f = to_form(@email_preset_changeset) %>
        <%= hidden_input f, :subject_template %>
        <%= hidden_input f, :body_template %>

        <div class="flex flex-col md:px-14 px-6 py-6">
          <b>Automation timing</b>
          <span class="text-base-250">Choose when you’d like your automation to run</span>
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
              <div class="flex flex-col ml-8 md:w-1/2">
                <div class="flex w-full my-2">
                  <div class="w-1/5">
                    <%= input f, :count, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer w-full" %>
                  </div>
                    <div class="ml-2 w-3/5">
                    <%= select f, :calendar, ["Hour", "Day", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                  </div>
                  <div class="ml-2 w-3/5">
                    <%= select f, :sign, [Before: "-", After: "+"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                  </div>
                </div>
                <%= if message = @email_preset_changeset.errors[:count] do %>
                  <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                <% end %>
              </div>
            <% end %>
          </div>
          <b>Email Status</b>
          <span class="text-base-250">Choose is if this email step is enabled or not to send</span>

          <div>
            <label class="flex pt-4">
              <%= checkbox f, :status, class: "peer hidden", checked: Changeset.get_field(@email_preset_changeset, :status) == :active %>
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
            <%= if message = @email_preset_changeset.errors[:status] do %>
              <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
            <% end %>
          </div>
        </div>
      </div>
    """
  end

  def step(%{step: :edit_email} = assigns) do
    ~H"""
      <div class="flex flex-row mt-2 items-center">
        <div class="flex mr-2">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-planning-300">
            <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
          </div>
        </div>
        <div class="flex flex-col ml-2">
          <p><b> <%= @pipeline.email_automation_category.type |> Atom.to_string() |> String.capitalize()%>:</b> <%= @pipeline.email_automation_sub_category.name %></p>
          <% c = to_form(@email_preset_changeset) %>
          <%= unless input_value(c, :immediately) do %>
            <% sign = input_value(c, :sign) %>
            <p class="text-sm text-base-250">Send email <%= input_value(c, :count) %> <%= String.downcase(input_value(c, :calendar)) %>  <%= if sign == "+", do: "after", else: "before" %> <%= String.downcase(@pipeline.name) %></p>
          <% end %>
        </div>
      </div>

      <hr class="my-8" />

      <% f = to_form(@email_preset_changeset) %>

      <div class="mr-auto">
        <div class="grid grid-row md:grid-cols-3 gap-6">
          <label class="flex flex-col">
            <b>Select email preset</b>
            <%= select_field f, :template_id, Shared.make_email_presets_options(@email_presets), class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>

          <label class="flex flex-col">
            <b>Subject Line</b>
            <%= input f, :subject_template, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
          <label class="flex flex-col">
            <b>Private Name</b>
            <%= input f, :private_name, placeholder: "Inquiry Email", class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
        </div>

        <div class="flex flex-col mt-4">
          <.input_label form={f} class="flex items-end justify-between mb-2 text-sm font-semibold" field={:body_template}>
            <b>Email Content</b>
            <.icon_button color="red-sales-300" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(f,:body_template)}>
              <p class="text-black">Clear</p>
            </.icon_button>
          </.input_label>
          <.quill_input f={f} id="quill_email_preset_input" html_field={:body_template} editor_class="min-h-[16rem]" placeholder={"Write your email content here"} enable_size={true} enable_image={true} current_user={@current_user}/>
        </div>
      </div>
    """
  end

  def step(%{step: :preview_email} = assigns) do
    ~H"""
      <div class="flex flex-row mt-2 mb-4 items-center">
        <div class="flex mr-2">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-planning-300">
            <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
          </div>
        </div>
        <div class="flex flex-col ml-2">
          <p><b> Job:</b> Upcoming Shoot Automation</p>
          <% c = to_form(@email_preset_changeset) %>
          <%= unless input_value(c, :immediately) do %>
            <% sign = input_value(c, :sign) %>
            <p class="text-sm text-base-250">Send email <%= input_value(c, :count) %> <%= String.downcase(input_value(c, :calendar)) %>  <%= if sign == "+", do: "after", else: "before" %> <%= String.downcase(@pipeline.name) %></p>
          <% end %>
        </div>
      </div>
      <span class="text-base-250">Check out how your client will see your emails. We’ve put in some placeholder data to visualize the variables.</span>

      <hr class="my-4" />

      <%= case @template_preview do %>
        <% nil -> %>
        <% :loading -> %>
          <div class="flex items-center justify-center w-full mt-10 text-xs">
            <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
            Loading...
          </div>
        <% content -> %>
          <div class="flex justify-center p-2 mt-4 rounded-lg bg-base-200">
            <iframe srcdoc={content} class="w-[30rem]" scrolling="no" phx-hook="IFrameAutoHeight" id="template-preview">
            </iframe>
          </div>
      <% end %>
    """
  end

  defp assign_changeset(
         %{
           assigns: %{
             email_preset: email_preset,
             step: step,
             current_user: current_user,
             pipeline: pipeline
           }
         } = socket,
         params
       ) do
    automation_params =
      if params do
        params
      else
        email_preset
        |> Map.put(:template_id, email_preset.id)
        |> Shared.prepare_email_preset_params()
      end
      |> Map.merge(%{
        "email_automation_pipeline_id" => pipeline.id,
        "organization_id" => current_user.organization_id,
        "step" => step
      })

    socket
    |> Shared.email_preset_changeset(email_preset, automation_params)
  end

  defp maybe_normalize_params(nil), do: nil

  defp maybe_normalize_params(params) do
    {_, params} =
      get_and_update_in(
        params,
        ["status"],
        &{&1, if(&1 == "true", do: :active, else: :disabled)}
      )

    params
  end

  defp save(
         %{
           assigns: %{
             email_preset_changeset: email_preset_changeset,
             job_types: job_types
           }
         } = socket
       ) do
    email_preset = email_preset_changeset |> current()
    selected_job_types = Enum.filter(job_types, & &1.selected)
    _preset_ids = Enum.map(selected_job_types, & &1.id)

    Ecto.Multi.new()
    # |> Ecto.Multi.delete_all(
    #   :delete_presets,
    #   from(ep in EmailPreset, where: ep.job_type in ^preset_ids
    #   and ep.organization_id == ^email_preset.organization_id
    #   and ep.email_automation_pipeline_id == ^email_preset.email_automation_pipeline_id)
    # )
    |> Ecto.Multi.insert_all(:email_preset, EmailPreset, fn _ ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      selected_job_types
      |> Enum.map(
        &%{
          status: email_preset.status,
          total_hours: email_preset.total_hours,
          condition: email_preset.condition,
          body_template: email_preset.body_template,
          type: email_preset.type,
          job_type: &1.id,
          name: email_preset.name,
          subject_template: email_preset.subject_template,
          position: email_preset.position,
          private_name: email_preset.private_name,
          email_automation_pipeline_id: email_preset.email_automation_pipeline_id,
          organization_id: email_preset.organization_id,
          inserted_at: now,
          updated_at: now
        }
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{email_preset: email_preset}} ->
        send(
          self(),
          {:update_automation, %{message: "Successfully created", email_preset: email_preset}}
        )

        :ok

      _ ->
        :error
    end

    socket
  end
end
