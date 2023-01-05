defmodule PicselloWeb.JobLive.ImportWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  require Ecto.Query

  alias Ecto.Changeset

  alias Picsello.{
    Job,
    Clients,
    Package
  }

  import PicselloWeb.Live.Shared
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  import PicselloWeb.JobLive.Shared,
    only: [
      job_form_fields: 1,
      process_cancel_upload: 2,
      presign_entry: 2,
      assign_uploads: 2,
      search_clients: 1
    ]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    auto_upload: true,
    max_entries: String.to_integer(Application.compile_env(:picsello, :documents_max_entries)),
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size)),
    external: &presign_entry/2,
    progress: &handle_progress/3
  ]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> assign_new(:step, fn -> :get_started end)
    |> assign(steps: [:get_started, :job_details, :package_payment, :invoice, :documents])
    |> assign_job_changeset(%{"client" => %{}})
    |> assign_uploads(@upload_options)
    |> assign(:ex_documents, [])
    |> assign(:another_import, nil)
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
    |> search_assigns()
    |> ok()
  end

  @impl true
  def render(%{searched_client: searched_client, selected_client: selected_client} = assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <div class="flex flex-col md:flex-row">
        <a {if step_number(@step, @steps) > 1, do: %{href: "#", phx_click: "back", phx_target: @myself, title: "back"}, else: %{}} class="flex w-full md:w-auto">
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

        <%= if step_number(@step, @steps) > 2 do%>
          <.client_name_box searched_client={searched_client} selected_client={selected_client} assigns={assigns} />
        <% end %>
      </div>

      <h1 class="mt-2 mb-4 text-s md:text-3xl">
        <strong class="font-bold">Import Existing Job:</strong>
        <%= heading_subtitle(@step) %>
      </h1>
      <.step {assigns} />
    </div>
    """
  end

  def step(%{step: :get_started} = assigns) do
    ~H"""
    <div {testid("import-job-card")} class="flex mt-8 overflow-hidden border rounded-lg border-base-200">
      <div class="w-4 border-r border-base-200 bg-blue-planning-300" />

      <div class="flex flex-col items-start w-full p-6 sm:flex-row">
        <div class="flex">
          <.icon name="camera-check" class="w-12 h-12 mt-2 text-blue-planning-300" />
          <h1 class="mt-2 ml-4 text-2xl font-bold sm:hidden">Import a job</h1>
        </div>
        <div class="flex flex-col sm:ml-4">
          <h1 class="hidden text-2xl font-bold sm:block">Import a job</h1>

          <p class="max-w-xl mt-1 mr-2">
            Use this option if you have shoot dates confirmed, have partial/scheduled payment, client client info, and a form of a contract or questionnaire.
          </p>
        </div>
        <button type="button" class="self-center w-full px-8 mt-6 ml-auto btn-primary sm:w-auto sm:mt-0" phx-click="go-job-details" phx-target={@myself}>Next</button>
      </div>
    </div>
    <div class="flex mt-6 overflow-hidden border rounded-lg border-base-200">
      <div class="w-4 border-r border-base-200 bg-base-200" />

      <div class="flex flex-col items-start w-full p-6 sm:flex-row">
        <div class="flex">
          <.icon name="three-people" class="w-12 h-12 mt-2 text-blue-planning-300" />
          <h1 class="mt-2 ml-4 text-2xl font-bold sm:hidden">Create a lead</h1>
        </div>
        <div class="flex flex-col sm:ml-4">
          <h1 class="hidden text-2xl font-bold sm:block">Create a lead</h1>

          <p class="max-w-xl mt-1 mr-2">
            Use this option if you have client contact info, are trying to book this person for a session/job but haven’t confirmed yet, and/or you aren’t ready to charge.
          </p>
        </div>
        <button type="button" class="self-center w-full px-8 mt-6 ml-auto btn-secondary sm:w-auto sm:mt-0" phx-click="create-lead" phx-target={@myself}>Next</button>
      </div>
    </div>
    """
  end

  def step(%{step: :job_details} = assigns) do
    ~H"""
    <.search_clients new_client={@new_client} search_results={@search_results} search_phrase={@search_phrase} selected_client={@selected_client} searched_client={@searched_client} current_focus={@current_focus} clients={@clients} myself={@myself}/>

    <.form for={@job_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <.job_form_fields form={f} job_types={@current_user.organization.profile.job_types} new_client={@new_client} myself={@myself} />

      <.footer>
        <button class="px-8 btn-primary" title="Next" type="submit" disabled={!@job_changeset.valid?} phx-disable-with="Next">
          Next
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
          Cancel
        </button>
      </.footer>
    </.form>
    """
  end

  def step(%{step: :package_payment, job_changeset: job_changeset} = assigns),
    do:
      Enum.into(assigns, %{job_type: Changeset.get_field(job_changeset, :type)})
      |> package_payment_step()

  def step(%{step: :invoice} = assigns), do: invoice_step(assigns)

  def step(%{step: :documents} = assigns),
    do:
      Enum.into(assigns, %{client_name: nil})
      |> documents_step()

  @impl true
  def handle_event("back", %{}, socket), do: go_back_event("back", %{}, socket) |> noreply()

  @impl true
  def handle_event("remove-payment", %{}, socket),
    do: remove_payment_event("remove-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event("add-payment", %{}, socket),
    do: add_payment_event("add-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event("validate", %{"package" => _} = params, socket),
    do: validate_package_event("validate", params, socket) |> noreply()

  @impl true
  def handle_event("validate", %{"custom_payments" => params}, socket),
    do: validate_payments_event("validate", %{"custom_payments" => params}, socket) |> noreply()

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :invoice}} = socket),
    do: invoice_submit_event("submit", %{}, socket) |> noreply()

  @impl true
  def handle_event("submit", params, %{assigns: %{step: :package_payment}} = socket),
    do: payment_package_submit_event("submit", params, socket) |> noreply()

  @impl true
  def handle_event("start_another_job", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, true)
      |> import_job_for_import_wizard()
      |> noreply()

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, false)
      |> import_job_for_import_wizard()
      |> noreply()

  @impl true
  def handle_event("create-lead", %{}, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> open_modal(
      PicselloWeb.JobLive.NewComponent,
      %{current_user: current_user}
    )
    |> noreply()
  end

  @impl true
  def handle_event("go-job-details", %{}, socket) do
    socket
    |> assign(step: :job_details)
    |> noreply()
  end

  @impl true
  def handle_event(
        "cancel-upload",
        %{"ref" => ref},
        %{assigns: %{ex_documents: ex_documents}} = socket
      ) do
    socket
    |> assign(:ex_documents, Enum.reject(ex_documents, &(&1.ref == ref)))
    |> process_cancel_upload(ref)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"job" => %{"client" => _client_params} = params}, socket) do
    socket |> assign_job_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"job" => %{"type" => _job_type} = params},
        %{assigns: %{searched_client: searched_client, selected_client: selected_client}} = socket
      ) do
    client_id =
      cond do
        searched_client -> searched_client.id
        selected_client -> selected_client.id
        true -> nil
      end

    socket
    |> assign_job_changeset(
      Map.put(
        params,
        "client_id",
        client_id
      )
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"job" => _params},
        %{assigns: %{step: :job_details, job_changeset: job_changeset}} = socket
      ) do
    case job_changeset do
      %{valid?: true} ->
        socket |> assign(step: :package_payment)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  defp search_assigns(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(:clients, Clients.find_all_by(user: current_user))
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:new_client, false)
    |> assign(current_focus: -1)
    |> assign_new(:selected_client, fn -> nil end)
  end

  defp assign_job_changeset(
         %{assigns: %{current_user: current_user}} = socket,
         params,
         action \\ nil
       ) do
    changeset =
      case params do
        %{"client_id" => _client_id} ->
          params
          |> Job.new_job_changeset()
          |> Map.put(:action, action)

        %{"client" => _client_params} ->
          params
          |> put_in(["client", "organization_id"], current_user.organization_id)
          |> Job.create_changeset()
          |> Map.put(:action, action)
      end

    assign(socket, job_changeset: changeset)
  end

  def show_link?(payment_changeset) do
    if remaining_to_collect(payment_changeset).amount == 0, do: true, else: false
  end
end
