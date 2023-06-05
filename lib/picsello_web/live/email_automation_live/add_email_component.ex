defmodule PicselloWeb.EmailAutomationLive.AddEmailComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.Shared.MultiSelect

  alias Picsello.{Jobs, JobType, GlobalSettings.Gallery}
  alias Picsello.EmailAutomation.EmailAutomationSetting
  alias Picsello.Marketing
  alias Ecto.Changeset

  @steps [:timing, :edit_email, :preview_email]

  @impl true
  def update(%{current_user: current_user, job_type: job_type} = assigns, socket) do
    job_types = Jobs.get_job_types_with_label(current_user.organization_id)
    |> Enum.map(&Map.put(&1, :selected, &1.id == job_type.id))

    socket
    |> assign(assigns)
    |> assign(job_types: job_types)
    |> assign(steps: @steps)
    |> assign(step: :timing)
    |> assign_changeset(%{"total_days" => 0})
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  @impl true
  def update(%{options: options}, socket) do
    socket
    |> assign(job_types: options)
    |> assign(steps: @steps)
    |> assign(step: :timing)
    |> assign_changeset(%{})
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

defp step_valid?(%{step: :timing, changeset: changeset, job_types: job_types}) do
  Enum.any?(job_types, &Map.get(&1, :selected, false))
  && changeset.valid?
end

defp step_valid?(%{step: :documents, contract_changeset: contract}), do: contract.valid?

defp step_valid?(assigns),
  do:
    Enum.all?(
      [
        assigns.changeset
      ],
      & &1.valid?
    )

  @impl true
  def handle_event("back", _, %{assigns: %{step: step, steps: steps}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    # |> assign_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"email_automation_setting" => params}, socket) do
    socket
    |> assign_changeset(maybe_normalize_params(params))
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "timing"}, %{assigns: assigns} = socket) do
    socket
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "edit_email"}, %{assigns: %{changeset: changeset} = assigns} = socket) do
    body_html = Ecto.Changeset.get_field(changeset, :body_html)
    Process.send_after(self(), {:load_template_preview, __MODULE__, body_html}, 50)

    socket
    |> assign(:template_preview, :loading)
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "preview_email", "email_automation_setting" => params}, %{assigns: assigns} = socket) do
    send(self(), {:update_automation, %{booking_event: "booking_event"}})

    socket
    # |> assign(step: next_step(assigns))
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
          <span class="font-bold">Add Wedding Email Step:</span>
          <%= case @step do %>
            <% :timing -> %> Timing
            <% :edit_email -> %> Edit Email
            <% :preview_email -> %> Preview Email
          <% end %>
        </h1>

        <.form for={@changeset} :let={f} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
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
                form={@job_type_changeset}
                on_change={fn options -> send_update(__MODULE__, id: __MODULE__, options: options) end}
                options={make_options(@changeset, @job_types)}
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
                form={@job_type_changeset}
                on_change={fn options -> send_update(__MODULE__, id: __MODULE__, options: options) end}
                options={make_options(@changeset, @job_types)}
              />
            </div>
          </.footer>
        </.form>
      </div>
    """
  end

  defp make_options(changeset, job_types) do
    job_types |> Enum.map(fn option ->
      Map.put(option, :label, String.capitalize(option.label))
    end)
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
          <div class="flex flex-row items-center mr-[600px]">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
              <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <span class="text-blue-planning-300 text-lg"><b>Send email:</b> Day Before Shoot</span>
          </div>
          <div class="flex ml-auto items-center">
            <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
              <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
            </div>
            <span>Job Automation</span>
          </div>
        </div>

        <% f = to_form(@changeset) %>

        <div class="px-14 py-6">
          <b>Automation timing</b>
          <span class="text-base-250">Choose when you’d like your automation to run</span>
          <div class="flex gap-4 flex-col my-4 w-1/2">
            <label class="flex items-center cursor-pointer">
              <%= radio_button(f, :immediately, true, class: "w-5 h-5 mr-4 radio") %>
              <p>Send immediately when event happens</p>
            </label>
            <label class="flex items-center cursor-pointer">
              <%= radio_button(f, :immediately, false, class: "w-5 h-5 mr-4 radio") %>
              <p>Send at a certain time</p>
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
          <span class="text-base-250">Choose is if this email step is enabled or not to send</span>

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
          <p><b> Job:</b> Day Before Shoot</p>
          <p class="text-sm text-base-250">Send email 2 hours before shoot</p>
        </div>
      </div>

      <hr class="my-8" />

      <% f = to_form(@changeset) %>

      <div class="mr-auto">
        <div class="grid grid-cols-3 gap-6">
          <label class="flex flex-col">
            <b>Select email preset</b>
            <%= select_field f, :email_preset, ["long text", "very long text", "super duper long text"], class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>

          <label class="flex flex-col">
            <b>Subject Line</b>
            <%= input f, :subject, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
          <label class="flex flex-col">
            <b>Private Name</b>
            <%= input f, :template_name, placeholder: "Inquiry Email", class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
        </div>

        <div class="flex flex-col mt-4">
          <.input_label form={f} class="flex items-end justify-between mb-2 text-sm font-semibold" field={:content}>
            <b>Email Content</b>
            <.icon_button color="red-sales-300" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(f,:content)}>
              <p class="text-black">Clear</p>
            </.icon_button>
          </.input_label>
          <.quill_input f={f} html_field={:body_html} text_field={:body_text} editor_class="min-h-[16rem]" placeholder={"Write your email content here"} enable_size={true} enable_image={true} current_user={@current_user}/>
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
          <p class="text-sm text-base-250">Send email 7 days before next upcoming shoot</p>
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

  defp assign_changeset(%{assigns: %{job_types: job_types, step: step, current_user: current_user} = assigns} = socket, params, action \\ nil) do
    job_type_params = Map.get(params, "job_type", %{}) |> Map.put("step", step)

    job_type_changeset = JobType.changeset(job_type_params)

    # package_pricing = current(package_pricing_changeset)
    # download = current(download_changeset)

    # print_credits_include_in_total = Map.get(package_pricing, :print_credits_include_in_total)
    # digitals_include_in_total = Map.get(download, :digitals_include_in_total)

    # multiplier_params = Map.get(params, "multiplier", %{}) |> Map.put("step", step)

    # multiplier_changeset =
    #   package
    #   |> Multiplier.from_decimal()
    #   |> Multiplier.changeset(
    #     multiplier_params,
    #     print_credits_include_in_total,
    #     digitals_include_in_total
    #   )

    # multiplier = current(multiplier_changeset)

    automation_params =
      params
      |> Map.merge(%{
        "email_automation_pipeline_id" => current_user.organization_id,
        "organization_id" => current_user.organization_id,
        "step" => step
      })

    changeset = EmailAutomationSetting.changeset(automation_params) |> Map.put(:action, action)

    # IO.inspect changeset
    # IO.inspect changeset |> current()

    assign(socket,
      changeset: changeset,
      job_type_changeset: job_type_changeset
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
