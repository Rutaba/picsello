defmodule PicselloWeb.JobLive.ImportWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Job}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.JobLive.Shared, only: [job_form_fields: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign(
      step: :get_started,
      steps: [:get_started, :job_details, :package_payment, :invoice]
    )
    |> assign_job_changeset(%{"client" => %{}})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <a {if step_number(@step, @steps) > 1, do: %{href: "#", phx_click: "back", phx_target: @myself, title: "back"}, else: %{}} class="flex">
        <span {testid("step-number")} class="px-2 py-0.5 mr-2 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300">
          Step <%= step_number(@step, @steps) %>
        </span>

        <ul class="flex items-center inline-block">
          <%= for step <- @steps do %>
            <li class={classes(
              "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
              %{ "bg-blue-planning-300" => step == @step, "bg-gray-200" => step != @step }
              )}>
            </li>
          <% end %>
        </ul>
      </a>

      <h1 class="mt-2 mb-4 text-3xl"><strong class="font-bold">Import Existing Job:</strong> <%= heading_subtitle(@step) %></h1>

      <.step {assigns} />
    </div>
    """
  end

  def heading_subtitle(step) do
    Map.get(
      %{
        get_started: "Get Started",
        job_details: "General Details",
        package_payment: "Package & Payment",
        invoice: "Custom Invoice"
      },
      step
    )
  end

  def step(%{step: :get_started} = assigns) do
    ~H"""
    <div class="flex overflow-hidden border border-base-200 rounded-lg mt-8">
      <div class="w-4 border-r border-base-200 bg-blue-planning-300" />

      <div class="flex p-6 items-start w-full">
        <.icon name="camera-check" class="w-12 h-12 text-blue-planning-300 mt-2" />
        <div class="flex flex-col ml-4">
          <h1 class="font-bold text-2xl">Import a job</h1>

          <p class="mt-1 mr-2 max-w-xl">
            Use this option if you have shoot dates confirmed, have partial/scheduled payment, client contact info, and a form of a contract or questionnaire.
          </p>
        </div>
        <button type="button" class="btn-primary self-center ml-auto px-8" phx-click="go-job-details" phx-target={@myself}>Next</button>
      </div>
    </div>
    <div class="flex overflow-hidden border border-base-200 rounded-lg mt-6">
      <div class="w-4 border-r border-base-200 bg-base-200" />

      <div class="flex p-6 items-start w-full">
        <.icon name="three-people" class="w-12 h-12 text-blue-planning-300 mt-2" />
        <div class="flex flex-col ml-4">
          <h1 class="font-bold text-2xl">Create a lead</h1>

          <p class="mt-1 mr-2 max-w-xl">
            Use this option if you have client contact info, are trying to book this person for a session/job but haven’t confirmed yet, and/or you aren’t ready to charge.
          </p>
        </div>
        <button type="button" class="btn-secondary self-center ml-auto px-8" phx-click="create-lead" phx-target={@myself}>Next</button>
      </div>
    </div>
    """
  end

  def step(%{step: :job_details} = assigns) do
    ~H"""
    <.form for={@job_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <.job_form_fields form={f} job_types={@current_user.organization.profile.job_types} />

      <.footer>
        <button class="btn-primary px-8" title="Next" type="submit" disabled={!@job_changeset.valid?} phx-disable-with="Next">
          Next
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
          Cancel
        </button>
      </.footer>
    </.form>
    """
  end

  @impl true
  def handle_event(
        "back",
        %{},
        %{assigns: %{step: step, steps: steps}} = socket
      ) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    |> noreply()
  end

  @impl true
  def handle_event("create-lead", %{}, socket) do
    socket
    |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
    |> noreply()
  end

  @impl true
  def handle_event("go-job-details", %{}, socket) do
    socket
    |> assign(step: :job_details)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_job_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"job" => params}, %{assigns: %{step: :job_details}} = socket) do
    case socket |> assign_job_changeset(params, :validate) do
      %{assigns: %{changeset: %{valid?: true}}} ->
        socket |> assign(step: :pricing) |> assign_job_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  defp assign_job_changeset(
         %{assigns: %{current_user: current_user}} = socket,
         params,
         action \\ nil
       ) do
    changeset =
      params
      |> put_in(["client", "organization_id"], current_user.organization_id)
      |> Job.create_changeset()
      |> Map.put(:action, action)

    assign(socket, job_changeset: changeset)
  end

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1
end
