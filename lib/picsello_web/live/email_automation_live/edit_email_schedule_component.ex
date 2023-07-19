defmodule PicselloWeb.EmailAutomationLive.EditEmailScheduleComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.Shared.ShortCodeComponent, only: [short_codes_select: 1]

  alias Picsello.{Repo, EmailPresets}
  alias Picsello.EmailAutomation.EmailSchedule
  alias PicselloWeb.EmailAutomationLive.Shared

  @steps [:edit_email, :preview_email]

  @impl true
  def update(
        %{
          job_types: job_types,
          job_type: job_type,
          pipeline: %{email_automation_category: %{type: type}, id: pipeline_id},
          email: email
        } = assigns,
        socket
      ) do
    job_types = Shared.get_selected_job_types(job_types, job_type)
    email_presets = EmailPresets.email_automation_presets(type, job_type.name, pipeline_id)

    socket
    |> assign(assigns)
    |> assign(job_types: job_types)
    |> assign(email_presets: remove_duplicate(email_presets, email))
    |> assign(email_preset: email)
    |> assign(steps: @steps)
    |> assign(step: :edit_email)
    |> assign(show_variables: false)
    |> assign(email_preset_changeset: EmailSchedule.changeset(email, %{}))
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

  defp remove_duplicate(email_presets, email_preset) do
    index = Enum.find_index(email_presets, &(&1.name == email_preset.name))
    if(index, do: List.delete_at(email_presets, index), else: email_presets) ++ [email_preset]
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
        %{"email_schedule" => params},
        %{assigns: %{email_preset: email_preset, email_presets: email_presets}} = socket
      ) do
    name = Map.get(params, "name", "1")

    preset =
      Enum.filter(email_presets, &(&1.name == name))
      |> List.first()
      |> Map.take([:body_template, :subject_template, :name])

    new_email_preset = Map.merge(email_preset, preset)

    params = if email_preset.name == name, do: params, else: nil

    socket
    |> assign(email_preset: new_email_preset)
    |> Shared.email_preset_changeset(new_email_preset, params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"email_automation_setting" => params},
        %{assign: %{email_preset: email_preset}} = socket
      ) do
    socket
    |> assign(
      email_preset_changeset:
        Shared.build_email_changeset(email_preset, maybe_normalize_params(params))
    )
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
  def handle_event("toggle-variables", %{"show-variables" => show_variables}, socket) do
    socket
    |> assign(show_variables: !String.to_atom(show_variables))
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.close_x />
        <.steps step={@step} steps={@steps} target={@myself} />

        <h1 class="mt-2 mb-4 text-3xl">
          <span class="font-bold">
          <%= case @step do %>
            <% :edit_email -> %> Edit
            <% :preview_email -> %> Preview
          <% end %>
          <%= String.capitalize(@job_type.name)%> Email</span>
        </h1>

        <.form for={@email_preset_changeset} :let={f} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
          <input type="hidden" name="step" value={@step} />

          <.step name={@step} f={f} {assigns} />

          <.footer class="pt-10">
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
          </.footer>
        </.form>
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
          <p><b> <%= @job_type.name |> String.capitalize()%>:</b> <%= @pipeline.email_automation_sub_category.name %></p>
          <p class="text-sm text-base-250">Send email 2 hours before shoot</p>
        </div>
      </div>

      <hr class="my-8" />

      <% f = to_form(@email_preset_changeset) %>
      <%= hidden_input f, :type, value: @pipeline.email_automation_category.type %>
      <%= hidden_input f, :email_automation_pipeline_id %>
      <%= hidden_input f, :job_id %>
      <%= hidden_input f, :position %>

      <div class="mr-auto">
        <div class="grid grid-row md:grid-cols-3 gap-6">
          <label class="flex flex-col">
            <b>Select email preset</b>
            <%= select_field f, :name, Enum.map(@email_presets, &{&1.name, &1.name}), class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
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
              <.quill_input f={f} id="quill_email_preset_input" html_field={:body_template} editor_class="min-h-[16rem] h-72" placeholder={"Write your email content here"} enable_size={true} enable_image={true} current_user={@current_user}/>
            </div>

            <div class={"flex flex-col w-full md:w-1/3 md:ml-2 min-h-[16rem] md:mt-0 mt-6 #{!@show_variables && "hidden"}"}>
              <.short_codes_select id="short-codes"/>
            </div>
          </div>
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
          <p><b> <%= @job_type.name |> String.capitalize()%>:</b> <%= @pipeline.email_automation_sub_category.name %></p>
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
             email: email
           }
         } = socket
       ) do
    changeset = Ecto.Changeset.put_change(email_preset_changeset, :id, email.id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :email_preset,
      fn _ -> changeset end,
      on_conflict: {:replace, [:name, :subject_template, :body_template, :private_name]},
      conflict_target: [:id]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{email_preset: email_preset}} ->
        send(
          self(),
          {:update_automation, %{message: "Successfully updated", email_preset: email_preset}}
        )

        :ok

      _ ->
        :error
    end

    socket
  end
end
