defmodule PicselloWeb.JobLive.ImportWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  require Ecto.Query

  alias Ecto.Changeset

  alias Picsello.{
    Job,
    Clients,
    Package,
    Profiles,
    UserCurrencies
  }

  import Phoenix.Component
  import PicselloWeb.Live.Shared
  import PicselloWeb.LiveModal, only: [footer: 1]
  import PicselloWeb.Shared.SelectionPopupModal, only: [render_modal: 1]

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
  def update(
        %{current_user: %{organization: organization}} = assigns,
        socket
      ) do
    %{currency: currency} = UserCurrencies.get_user_currency(organization.id)

    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1, currency: currency} end)
    |> assign_new(:step, fn -> :get_started end)
    |> assign(steps: [:get_started, :job_details, :package_payment, :invoice, :documents])
    |> assign_job_changeset(%{"client" => %{}})
    |> assign_uploads(@upload_options)
    |> assign(:ex_documents, [])
    |> assign(:another_import, nil)
    |> then(fn %{assigns: %{package: %{currency: currency}}} = socket ->
      socket
      |> assign(:currency, currency)
      |> assign(:currency_symbol, Money.Currency.symbol!(currency))
    end)
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
    |> search_assigns()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.render_modal
          {assigns}
          heading="Import Existing Job:"
          heading_subtitle={heading_subtitle(@step)}
          title_one="Import a job"
          subtitle_one="Use this option if you have shoot dates confirmed, have partial/scheduled payment, client client info, and a form of a contract or questionnaire."
          icon_one="camera-check"
          btn_one_event="go-job-details"
          title_two="Create a lead"
          subtitle_two="Use this option if you have client contact info, are trying to book this person for a session/job but haven’t confirmed yet, and/or you aren’t ready to charge."
          icon_two="three-people"
          btn_two_event="create-lead"
        />
      </div>
    """
  end

  @impl true
  def handle_event("back", %{}, socket), do: go_back_event("back", %{}, socket) |> noreply()

  @impl true
  def handle_event("edit-digitals", %{"type" => type}, socket) do
    socket
    |> assign(:show_digitals, type)
    |> noreply()
  end

  @impl true
  def handle_event("remove-payment", %{}, socket),
    do: remove_payment_event("remove-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event("add-payment", %{}, socket),
    do: add_payment_event("add-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event(
        event,
        params,
        %{assigns: %{currency: currency, currency_symbol: currency_symbol}} = socket
      )
      when event in ~w(validate submit) and not is_map_key(params, "parsed?") do
    __MODULE__.handle_event(
      event,
      Picsello.Currency.parse_params_for_currency(
        params,
        {currency_symbol, currency}
      ),
      socket
    )
  end

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
  def handle_event("submit", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, false)
      |> import_job_for_import_wizard()
      |> noreply()

  @impl true
  def handle_event("start_another_job", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, true)
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

      _ ->
        socket
    end
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  def step(%{step: :job_details} = assigns) do
    ~H"""
    <.search_clients new_client={@new_client} search_results={@search_results} search_phrase={@search_phrase} selected_client={@selected_client} searched_client={@searched_client} current_focus={@current_focus} clients={@clients} myself={@myself}/>

    <.form for={@job_changeset} :let={f} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
      <.job_form_fields myself={@myself} form={f} new_client={@new_client} job_types={Profiles.enabled_job_types(@current_user.organization.organization_job_types)} />

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

  def step(%{step: :package_payment, job_changeset: job_changeset} = assigns) do
    job_type = Changeset.get_field(job_changeset, :type)

    Enum.into(assigns, %{job_type: job_type, show_digitals: job_type, myself: self()})
    |> package_payment_step()
  end

  def step(%{step: :invoice} = assigns), do: invoice_step(assigns)

  def step(%{step: :documents} = assigns),
    do:
      Enum.into(assigns, %{client_name: nil})
      |> documents_step()

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
          |> Job.create_job_changeset()
          |> Map.put(:action, action)
      end

    assign(socket, :job_changeset, changeset)
  end

  def show_link?(payment_changeset) do
    if remaining_to_collect(payment_changeset).amount == 0, do: true, else: false
  end
end
