defmodule PicselloWeb.EmailAutomationLive.AddEmailComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.Shared.MultiSelect
  import PicselloWeb.Shared.ShortCodeComponent, only: [short_codes_select: 1]
  import PicselloWeb.EmailAutomationLive.Shared

  alias Picsello.{Repo, EmailPresets, EmailPresets.EmailPreset, Utils}
  alias Ecto.Changeset

  @steps [:timing, :edit_email, :preview_email]

  @impl true
  def update(
        %{
          job_type: job_type,
          job_types: job_types,
          pipeline: %{email_automation_category: %{type: type}, id: pipeline_id}
        } = assigns,
        socket
      ) do
    job_types = get_selected_job_types(job_types, job_type)

    email_presets = EmailPresets.email_automation_presets(type, job_type.name, pipeline_id)

    socket
    |> assign(assigns)
    |> assign(job_types: job_types)
    |> assign(job: nil)
    |> assign(email_presets: email_presets)
    |> assign(email_preset: List.first(email_presets))
    |> assign(steps: @steps)
    |> assign(step: :timing)
    |> assign(show_variables: false)
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
      |> validate?(assigns.job_types)

  @impl true
  def handle_event("back", _, %{assigns: %{step: step, steps: steps}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    |> noreply()
  end

  @impl true
  def handle_event("toggle-variables", %{"show-variables" => show_variables}, socket) do
    socket
    |> assign(show_variables: !String.to_atom(show_variables))
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
    selected_preset = Enum.filter(email_presets, &(&1.id == template_id))

    new_email_preset =
      if Enum.any?(selected_preset) do
        selected_preset
      else
        email_presets
      end
      |> List.first()
      |> Map.merge(%{
        email_automation_pipeline_id: pipeline.id,
        organization_id: current_user.organization_id
      })

    params = if email_preset.id == template_id, do: params, else: nil

    socket
    |> assign(email_preset: new_email_preset)
    |> email_preset_changeset(new_email_preset, maybe_normalize_params(params))
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
      |> email_preset_changeset(email_preset)
    end
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "edit_email"},
        %{
          assigns:
            %{email_preset_changeset: changeset, current_user: current_user, job: job} = assigns
        } = socket
      ) do
    body_html =
      Ecto.Changeset.get_field(changeset, :body_template)
      |> :bbmustache.render(get_sample_values(current_user, job), key_type: :atom)
      |> Utils.normalize_body_template()

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
        <%= hidden_input f, :job_type, value: @job_type.name %>
        <%= hidden_input f, :name %>
        <%= hidden_input f, :position %>

          <input type="hidden" name="step" value={@step} />

          <.step name={@step} f={f} {assigns} />

          <.footer class="pt-10">
            <div class="mr-auto md:hidden flex w-full">
              <.multi_select
                id="job_types_mobile"
                select_class="w-full font-bold"
                placeholder_class="opacity-100"
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
                select_class="w-52 font-bold"
                placeholder_class="opacity-100"
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

        <div class="bg-base-200 p-4 flex flex-col lg:flex-row rounded-t-lg">
              <div class="flex items-center">
                <div>
                  <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
                    <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                  </div>
                </div>
                <div class="text-blue-planning-300 text-lg"><b>Send email:</b> <%= @pipeline.name %></div>
              </div>
              <div class="flex lg:ml-auto items-center mt-3 lg:mt-0">
                <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
                  <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
                </div>
                <span class="font-semibold">Job Automation</span>
              </div>
            </div>

        <% f = to_form(@email_preset_changeset) %>
        <%= hidden_input f, :subject_template %>
        <%= hidden_input f, :template_id %>
        <%= hidden_input f, :body_template %>

        <div class="flex flex-col px-6 py-6 md:px-14">
          <div class="flex flex-col lg:flex-row ">
            <div class="flex flex-col w-full lg:w-1/2 lg:pr-6 md:border-base-200 pr-6">
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
                  <div class="flex flex-col ml-8">
                    <div class="flex w-full my-2">
                      <div class="w-1/5 min-w-[40px]">
                        <%= input f, :count, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer w-full text-center" %>
                      </div>
                        <div class="ml-2 w-3/5">
                        <%= select f, :calendar, ["Hour", "Day", "Month", "Year"], wrapper_class: "mt-4", class: "w-full bg-white p-3 border rounded-lg border-base-200", phx_update: "update" %>
                      </div>
                      <div class="ml-2 w-3/5">
                        <%= select f, :sign, make_sign_options(@pipeline.state), wrapper_class: "mt-4", class: "w-full bg-white p-3 border rounded-lg border-base-200", phx_update: "update" %>
                      </div>
                    </div>
                    <%= if message = @email_preset_changeset.errors[:count] do %>
                      <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                    <% end %>
                  </div>
                <% end %>
              </div>
              <%= if message = @email_preset_changeset.errors[:status] do %>
                <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
              <% end %>
              </div>
              <%!-- <%= unless input_value(f, :immediately) do %>
                <div class="flex flex-col w-full lg:w-1/2 lg:pl-6 lg:border-l md:border-base-200">
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
                    <%= if input_value(f, :normally) === "false" do %>
                      <div class="flex my-2 ml-8">
                        <%= select_field f, :condition, ["Client doesn’t respond by email send time", "Month", "Year"], wrapper_class: "mt-4", class: "w-full pr-10 border rounded-lg border-base-200", phx_update: "update" %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %> --%>
            </div>
            <hr class="my-4 flex md:hidden">
            <div>
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
            </div>
          </div>
        </div>
      </div>
    """
  end

  def step(%{step: :edit_email} = assigns) do
    ~H"""
      <.email_header pipeline={@pipeline} email={current(@email_preset_changeset)}/>
      <hr class="my-8" />

      <% f = to_form(@email_preset_changeset) %>
      <%= hidden_input f, :immediately %>
      <%= hidden_input f, :count %>
      <%= hidden_input f, :calendar %>
      <%= hidden_input f, :sign %>
      <%= hidden_input f, :status %>

      <div class="mr-auto">
        <div class="grid grid-row md:grid-cols-3 gap-6">
          <label class="flex flex-col">
            <b>Select email preset</b>
            <%= select_field f, :template_id, make_email_presets_options(@email_presets), class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
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
          <.input_label form={f} class="flex items-end mb-2 text-sm font-semibold" field={:body_template}>
            <b>Email Content</b>
            <.icon_button color="red-sales-300" class="ml-auto mr-4" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(f,:body_template)}>
              <p class="text-black">Clear</p>
            </.icon_button>
            <.icon_button color="blue-planning-300" class={@show_variables && "hidden"} icon="vertical-list" id="view-variables" phx-click="toggle-variables" phx-value-show-variables={"#{@show_variables}"} phx-target={@myself}>
              <p class="text-blue-planning-300">View email variables</p>
            </.icon_button>
          </.input_label>

          <div class="flex flex-col md:flex-row">
            <div id="quill-wrapper" class={"w-full #{@show_variables && "md:w-2/3"}"}>
            <.quill_input f={f} id="quill_email_preset_input" html_field={:body_template} editor_class="min-h-[16rem]" placeholder={"Write your email content here"} enable_size={true} enable_image={true} current_user={@current_user}/>
            </div>

            <div class={"flex flex-col w-full md:w-1/3 md:ml-2 min-h-[16rem] md:mt-0 mt-6 #{!@show_variables && "hidden"}"}>
              <.short_codes_select id="short-codes" show_variables={"#{@show_variables}"} target={@myself} job_type={@pipeline.email_automation_category.type} current_user={@current_user}/>
            </div>
          </div>
        </div>
      </div>
    """
  end

  def step(%{step: :preview_email} = assigns) do
    ~H"""
      <.email_header pipeline={@pipeline} email={current(@email_preset_changeset)}/>
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
            <iframe srcdoc={content} class="w-[30rem]" scrolling="no" phx-hook="IFrameAutoHeight" phx-update="ignore" id="template-preview">
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
        |> prepare_email_preset_params()
      end
      |> Map.merge(%{
        "email_automation_pipeline_id" => pipeline.id,
        "organization_id" => current_user.organization_id,
        "step" => step
      })

    socket
    |> email_preset_changeset(email_preset, automation_params)
  end

  defp save(
         %{
           assigns: %{
             pipeline: pipeline,
             email_preset_changeset: email_preset_changeset,
             job_types: job_types,
             current_user: %{organization_id: organization_id}
           }
         } = socket
       ) do
    email_preset = email_preset_changeset |> current()
    selected_job_types = Enum.filter(job_types, & &1.selected)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:email_preset, EmailPreset, fn _ ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      selected_job_types
      |> Enum.map(
        &%{
          state: pipeline.state,
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
          organization_id: organization_id,
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
          {:update_automation,
           %{message: "Email template successfully created", email_preset: email_preset}}
        )

        :ok

      _ ->
        :error
    end

    socket
  end
end
