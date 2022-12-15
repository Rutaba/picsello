defmodule PicselloWeb.JobLive.ImportWizard do
  @moduledoc false

  use PicselloWeb, :live_component

  alias Ecto.Changeset

  alias Picsello.{
    Job,
    Jobs,
    Clients,
    Package,
    Packages.Download,
    Packages.PackagePricing,
    Repo,
    BookingProposal,
    Galleries.Workers.PhotoStorage
  }

  alias PicselloWeb.Live.Shared.CustomPayments

  import PicselloWeb.Live.Shared
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  import PicselloWeb.JobLive.Shared,
    only: [
      job_form_fields: 1,
      drag_drop: 1,
      check_max_entries: 1,
      check_dulplication: 1,
      renew_uploads: 3,
      files_to_upload: 1,
      error_action: 1,
      search_clients: 1
    ]

  import PicselloWeb.PackageLive.Shared,
    only: [package_basic_fields: 1, digital_download_fields: 1, current: 1]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    max_entries: String.to_integer(Application.compile_env(:picsello, :documents_max_entries)),
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size))
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
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
    |> allow_upload(:documents, @upload_options)
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
          <div class="flex hover:cursor-auto mt-2">
            <div class="ml-3 mr-3 text-base-200 hidden md:block">|</div>
            <.icon name="client-icon" class="w-7 h-7 mr-1"></.icon>
            <p class="font-bold">Client: <span class="font-normal"><%=
            cond do
              searched_client -> searched_client.name
              selected_client -> selected_client.name
              true -> Changeset.get_field(assigns.job_changeset.changes.client, :name)
            end
          %></span></p>
          </div>
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

  def step(%{step: :package_payment, package_changeset: package_changeset} = assigns) do
    base_price_zero? = base_price_zero?(package_changeset)

    ~H"""
    <.form for={@package_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <h2 class="text-xl font-bold">Package Details</h2>
      <.package_basic_fields form={f} job_type={Changeset.get_field(@job_changeset, :type)} />

      <hr class="mt-8 border-gray-100">

      <h2 class="mt-4 mb-2 text-xl font-bold">Package Price</h2>
      <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <label for={input_id(f, :base_price)}>
          The amount you’ve charged for your job <p>(including download credits)</p>
        </label>
        <div class="flex items-center justify-end w-full mt-6 sm:w-auto">
          <span class="mx-3 text-2xl font-bold text-base-250">+</span>
          <%= input f, :base_price, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg text-center", phx_hook: "PriceMask" %>
        </div>
      </div>
      <div class="flex flex-col items-start justify-between w-full mt-4 sm:items-center sm:flex-row sm:w-auto">
        <label for={input_id(f, :print_credits)}>
          How much of the creative session fee is for print credits?
        </label>
        <div class="flex items-center justify-end w-full mt-6 sm:w-auto">
          <span class="mx-4 text-2xl font-bold text-base-250">&nbsp;</span>
          <%= input f, :print_credits, disabled: base_price_zero?, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg text-center", phx_hook: "PriceMask" %>
        </div>
      </div>

      <hr class="hidden mt-4 border-gray-100 sm:block">

      <div class="flex flex-col items-start justify-between w-full mt-4 sm:items-center sm:flex-row sm:w-auto sm:mt-0">
        <label for={input_id(f, :collected_price)}>
          The amount you’ve already collected
        </label>
        <div class="flex items-center justify-end w-full mt-6 sm:w-auto">
          <span class="mx-3 text-2xl font-bold text-base-250">-</span>
          <%= input f, :collected_price, disabled: base_price_zero?, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg text-center", phx_hook: "PriceMask" %>
        </div>
      </div>

      <dl class="flex flex-col justify-between mt-4 text-lg font-bold sm:flex-row">
        <dt>Remaining balance to collect with Picsello</dt>
        <dd class="w-full p-6 py-2 mt-2 text-center rounded-lg sm:w-32 text-green-finances-300 bg-green-finances-100/30 sm:mt-0"><%= total_remaining_amount(@package_changeset) %></dd>
      </dl>

      <hr class="mt-4 border-gray-100">

      <.digital_download_fields package_form={f} download={@download_changeset} package_pricing={@package_pricing_changeset} />

      <.step_footer
        title="Next"
        disabled={Enum.any?([@download_changeset, @package_pricing_changeset, @package_changeset], &(!&1.valid?))}
        myself={@myself}
      />
    </.form>
    """
  end

  def step(%{step: :invoice, package_changeset: package_changeset} = assigns) do
    remaining_amount_zero? = remaining_amount_zero?(package_changeset)

    ~H"""
    <.form for={@payments_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <h3 class="font-bold">Balance to collect: <%= total_remaining_amount(@package_changeset) %></h3>

      <div class={classes("flex items-center bg-blue-planning-100 rounded-lg my-4 py-4", %{"hidden" => !remaining_amount_zero?})}}>
        <.intro_hint class="ml-4" content={"#"}/>
        <div class="pl-2">
          <b>Since your remaining balance is $0.00, we'll mark your job as paid for.</b> Make sure to follow up with any emails as needed to your client.
        </div>
      </div>

      <div class={classes(%{"pointer-events-none opacity-40" => remaining_amount_zero?})}>
        <%= inputs_for f, :payment_schedules, fn p -> %>
          <div {testid("payment-#{p.index + 1}")}>
            <div class="flex items-center mt-4">
              <div class="mb-2 text-xl font-bold">Payment <%= p.index + 1 %></div>

              <%= if p.index > 0 do %>
                <.icon_button class="ml-8" title="remove" phx-click="remove-payment" phx-target={@myself} color="red-sales-300" icon="trash">
                  Remove
                </.icon_button>
              <% end %>
            </div>

            <div class="flex flex-wrap w-full mb-8">
              <div class="w-full sm:w-auto">
                <%= labeled_input p, :due_date, label: "Due", type: :date_input, placeholder: "mm/dd/yyyy", class: "sm:w-64 w-full px-4 text-lg" %>
              </div>
              <div class="w-full sm:ml-16 sm:w-auto">
                <%= labeled_input p, :price, label: "Payment amount", placeholder: "$0.00", class: "sm:w-36 w-full px-4 text-lg text-center", phx_hook: "PriceMask" %>
              </div>
            </div>
          </div>
        <% end %>

        <%= if f |> current() |> Map.get(:payment_schedules) |> Enum.count == 1 do %>
          <button type="button" title="add" phx-click="add-payment" phx-target={@myself} class="px-2 py-1 mb-8 btn-secondary">
            Add new payment
          </button>
        <% end %>

        <div class="text-xl font-bold">
          Remaining to collect:
          <%= case remaining_to_collect(@payments_changeset) do %>
            <% value -> %>
            <%= if Money.zero?(value) do %>
              <span class="text-green-finances-300"><%= value %></span>
            <% else %>
              <span class="text-red-sales-300"><%= value %></span>
            <% end %>
          <% end %>
        </div>
        <p class="mb-2 text-sm italic font-light">limit two payments</p>
      </div>

      <.step_footer
        title="Next"
        disabled={if remaining_amount_zero?, do: false, else: !@payments_changeset.valid?}
        myself={@myself}
      />
    </.form>
    """
  end

  def step(%{step: :documents} = assigns) do
    ~H"""
    <form phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
      <.drag_drop upload_entity={@uploads.documents} supported_types=".PDF, .docx, .txt" />
      <div class={classes("uploadingList__wrapper mt-8", %{"hidden" => Enum.empty?(@uploads.documents.entries)})}>
        <div class="grid grid-cols-5 pb-4 items-center text-lg font-bold">
          <span class="col-span-2">Name</span>
          <span class="col-span-2">Status</span>
          <span class="ml-auto">Actions</span>
        </div>
        <hr class="md:block border-blue-planning-300 border-2 mb-2">
        <%= Enum.filter(@uploads.documents.entries, & !&1.valid?) |> Enum.map(fn entry -> %>
          <.files_to_upload myself={@myself} entry={entry}>
            <%= for error <- upload_errors(@uploads.documents, entry) do %>
            <.error_action error={error} entry={entry} target={@myself} />
            <% end %>
          </.files_to_upload>
        <% end) %>
        <%= Enum.filter(@uploads.documents.entries, & &1.valid?) |> Enum.map(fn entry -> %>
          <.files_to_upload myself={@myself}  entry={entry}>
            <p class="btn items-center">Uploaded</p>
          </.files_to_upload>
        <% end) %>
      </div>

      <.step_footer title="Finish" disabled={Enum.any?(@uploads.documents.entries, & !&1.valid?)} myself={@myself} />
    </form>
    """
  end

  defp step_footer(assigns) do
    ~H"""
    <.footer>
      <button class="px-8 btn-primary" title={@title} type="submit" disabled={@disabled} phx-disable-with={@title}>
        <%= @title %>
      </button>
      <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>Go back</button>
    </.footer>
    """
  end

  @impl true
  def handle_event(
        "back",
        %{},
        %{assigns: %{step: step, steps: steps, selected_client: selected_client}} = socket
      ) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(
      step:
        if(!is_nil(selected_client) and previous_step == :get_started,
          do: step,
          else: previous_step
        )
    )
    |> noreply()
  end

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
        "remove-payment",
        %{},
        %{assigns: %{payments_changeset: payments_changeset}} = socket
      ) do
    payment_schedule =
      payments_changeset
      |> current()
      |> Map.get(:payment_schedules)
      |> Enum.at(0)
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    params = %{"payment_schedules" => [payment_schedule]}

    socket
    |> assign_payments_changeset(params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-payment",
        %{},
        %{assigns: %{payments_changeset: payments_changeset}} = socket
      ) do
    payment_schedules =
      payments_changeset
      |> current()
      |> Map.get(:payment_schedules)
      |> Enum.map(fn payment ->
        payment
        |> Map.from_struct()
        |> Map.new(fn {k, v} -> {to_string(k), v} end)
      end)

    params = %{"payment_schedules" => payment_schedules ++ [%{}]}

    socket
    |> assign_payments_changeset(params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event(
        "retry",
        %{"ref" => ref},
        %{assigns: %{uploads: %{documents: %{entries: entries}}}} = socket
      ) do
    entry = Enum.find(entries, &(&1.ref == ref))

    entries
    |> Enum.reject(&(&1.ref == ref))
    |> Enum.concat([%{entry | valid?: true}])
    |> renew_uploads(entry, socket)
    |> check_max_entries()
    |> check_dulplication()
    |> noreply()
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
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
  def handle_event("validate", %{"package" => _} = params, socket) do
    socket |> assign_package_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"custom_payments" => params}, socket) do
    socket |> assign_payments_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["documents"]},
        socket
      ) do
    socket
    |> check_max_entries()
    |> check_dulplication()
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
  def handle_event("submit", params, %{assigns: %{step: :package_payment}} = socket) do
    case socket |> assign_package_changeset(params, :validate) do
      %{
        assigns: %{
          package_changeset: %{valid?: true} = package_changeset,
          download_changeset: %{valid?: true},
          package_pricing_changeset: %{valid?: true},
          payments_changeset: payments_changeset
        }
      } ->
        socket
        |> assign(
          step: :invoice,
          payments_changeset:
            payments_changeset
            |> Changeset.put_change(
              :remaining_price,
              total_remaining_amount(package_changeset)
            )
        )
        |> noreply()

      socket ->
        socket
        |> noreply()
    end
  end

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :documents}} = socket) do
    import_job(socket)
  end

  def handle_event("submit", %{}, %{assigns: %{step: :invoice}} = socket) do
    socket
    |> assign(:step, :documents)
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  defp import_job(
         %{
           assigns:
             %{
               selected_client: selected_client,
               searched_client: searched_client,
               job_changeset: job_changeset
             } = _assigns
         } = socket
       ) do
    job = job_changeset |> Changeset.apply_changes()

    client = get_client(selected_client, searched_client, job.client)

    case insert_multi(client, socket) do
      {:ok, %{job: %Job{id: job_id} = job}} ->
        upload_docs(job, socket)

        socket |> push_redirect(to: Routes.job_path(socket, :jobs, job_id)) |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  defp upload_docs(
         job,
         %{
           assigns:
             %{
               uploads: uploads
             } = _assigns
         } = socket
       ) do
    uploads.documents.entries
    |> Enum.filter(& &1.valid?)
    |> Task.async_stream(fn entry ->
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        url = Job.document_path(job.id, entry.client_name)
        {:ok, _} = PhotoStorage.insert(url, File.read!(path))

        {:ok, %{url: url, name: entry.client_name}}
      end)
    end)
    |> Enum.reduce([], fn {:ok, document}, acc -> [document | acc] end)
    |> then(&Job.document_changeset(job, %{documents: &1}))
    |> Repo.update!()
  end

  defp insert_multi(
         client,
         %{
           assigns:
             %{
               current_user: current_user,
               job_changeset: job_changeset,
               package_changeset: package_changeset
             } = _assigns
         } = socket
       ) do
    Ecto.Multi.new()
    |> Jobs.maybe_upsert_client(client, current_user)
    |> Ecto.Multi.insert(:job, fn changes ->
      job_changeset
      |> Changeset.delete_change(:client)
      |> Changeset.put_change(:client_id, changes.client.id)
      |> Map.put(:action, nil)
    end)
    |> Ecto.Multi.insert(:package, package_changeset |> Map.put(:action, nil))
    |> Ecto.Multi.update(:job_update, fn changes ->
      Job.add_package_changeset(changes.job, %{package_id: changes.package.id})
    end)
    |> Ecto.Multi.insert(:proposal, fn changes ->
      BookingProposal.create_changeset(%{job_id: changes.job.id})
    end)
    |> maybe_insert_payment_schedules(socket)
    |> Repo.transaction()
  end

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

  defp get_client(selected_client, searched_client, client) do
    cond do
      selected_client ->
        selected_client

      searched_client ->
        searched_client

      true ->
        client
    end
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

  defp assign_package_changeset(
         %{assigns: %{current_user: current_user}} = socket,
         params,
         action \\ nil
       ) do
    package_pricing_changeset =
      Map.get(params, "package_pricing", %{})
      |> PackagePricing.changeset()
      |> Map.put(:action, action)

    download_changeset =
      socket.assigns.package
      |> Download.from_package()
      |> Download.changeset(Map.get(params, "download", %{}))
      |> Map.put(:action, action)

    download = current(download_changeset)

    package_changeset =
      params
      |> Map.get("package", %{})
      |> PackagePricing.handle_package_params(params)
      |> Map.merge(%{
        "download_count" => Download.count(download),
        "download_each_price" => Download.each_price(download),
        "organization_id" => current_user.organization_id,
        "buy_all" => Download.buy_all(download)
      })
      |> Package.import_changeset()
      |> Map.put(:action, action)

    assign(socket,
      package_changeset: package_changeset,
      download_changeset: download_changeset,
      package_pricing_changeset: package_pricing_changeset
    )
  end

  defp assign_payments_changeset(
         %{assigns: %{package_changeset: package_changeset}} = socket,
         params,
         action \\ nil
       ) do
    changeset =
      params
      |> Map.put("remaining_price", total_remaining_amount(package_changeset))
      |> CustomPayments.changeset()
      |> Map.put(:action, action)

    assign(socket, payments_changeset: changeset)
  end
end
