defmodule PicselloWeb.Live.ClientLive.ClientFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{
    Job,
    Repo,
    Client,
    Clients,
    Package,
    Packages.Download,
    Packages.PackagePricing,
    BookingProposal,
    Galleries.Workers.PhotoStorage
  }

  alias PicselloWeb.Live.Shared.CustomPayments

  alias Ecto.Changeset

  import PicselloWeb.LiveModal, only: [footer: 1]
  import PicselloWeb.Live.Shared

  import PicselloWeb.PackageLive.Shared,
    only: [package_basic_fields: 1, digital_download_fields: 1, current: 1]

  import PicselloWeb.JobLive.Shared,
    only: [
      drag_drop: 1,
      check_max_entries: 1,
      check_dulplication: 1,
      renew_uploads: 3,
      files_to_upload: 1,
      error_action: 1
    ]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    max_entries: String.to_integer(Application.compile_env(:picsello, :documents_max_entries)),
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size))
  ]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> assign_changeset()
    |> assign(
      step: :add_client,
      steps: [:add_client, :package_payment, :invoice, :documents]
    )
    |> assign(:pre_picsello_client, false)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> allow_upload(:documents, @upload_options)
    |> assign_job_changeset(%{})
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
    |> ok()
  end

  @impl true
  def render(%{changeset: changeset} = assigns) do
    ~H"""
      <div class="flex flex-col modal">

        <%= if @pre_picsello_client do %>
          <div class="flex mb-2">
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

            <%= if step_number(@step, @steps) > 1 do%>
              <div class="flex hover:cursor-auto">
                <div class="ml-3 mr-3 text-base-200">|</div>
                <.icon name="client-icon" class="w-7 h-7 mr-1"></.icon>
                <p class="font-bold">Client: <span class="font-normal"><%= Changeset.get_field(changeset, :name) %></span></p>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mt-2 mb-4 text-3xl"><strong class="font-bold"><%= if @client, do: "Edit Client: ", else: "Add Client: "%></strong> <%= heading_subtitle(@step) %></h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.step {assigns} />
      </div>
    """
  end

  def step(%{step: :add_client} = assigns) do
    ~H"""
      <.form for={@changeset} let={f} phx_submit={:submit} phx-change="validate" phx-target={@myself}>
        <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
          <%= labeled_input f, :name, placeholder: "First and last name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500" %>
          <%= labeled_input f, :email, type: :email_input, placeholder: "email@example.com", phx_debounce: "500" %>
          <%= labeled_input f, :phone, type: :telephone_input, placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500" %>
          <%= labeled_input f, :address, placeholder: "Street Address", phx_debounce: "500", optional: true %>
        </div>
        <%= if !@client do %>
          <div class="mt-2">
            <div class="flex items-center justify-between mb-2">
              <%= label_for f, :notes, label: "Notes", optional: true %>

              <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(f,:notes)}>
                Clear
              </.icon_button>
            </div>

            <fieldset>
              <%= input f, :notes, type: :textarea, placeholder: "Optional notes", class: "w-full max-h-60", phx_hook: "AutoHeight", phx_update: "ignore" %>
            </fieldset>
          </div>

          <h1 class="mt-5 text-xl font-bold">Pre-Picsello Client</h1>
          <label class="flex items-center mt-4">
            <input type="checkbox" class="w-6 h-6 mt-1 checkbox" phx-click="toggle-pre-picsello" checked={@pre_picsello_client} phx-target={@myself} />
            <p class="ml-3"> This is an old client and I want to add some historic information</p>
          </label>
          <p class="ml-8"><i>(Adds a few more steps - if you don't know what this is, leave unchecked)</i></p>
          <%= if @pre_picsello_client do %>
            <div id="show-div" class="sm:col-span-3 mt-3">
              <p class="ml-8 mt-4 font-bold">In order for this client import to sync with your Picsello account, select the type of job to start import.</p>
              <div class="ml-8 grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
                <%= for job_type <- @job_types do %>
                  <.job_type_option type="radio" class={"checkbox-#{job_type}"} name={input_name(f, :type)} job_type={job_type} checked={input_value(f, :type) == job_type} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
        <div class="pt-40"></div>
        <div {testid("modal-buttons")} class="sticky px-4 -m-4 bg-white -bottom-6 sm:px-8 sm:-m-8 sm:-bottom-8">
          <div class="flex flex-col py-6 bg-white gap-2 sm:flex-row-reverse">
            <%= if @pre_picsello_client do %>
              <button class="btn-primary" title="next" disabled={!(@changeset.valid? and input_value(f, :type))} type="submit">
                Next
              </button>
            <% else %>
              <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
                Save
              </button>
            <% end %>

            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          </div>
        </div>
      </.form>
    """
  end

  def step(%{step: :package_payment, package_changeset: package_changeset} = assigns) do
    base_price_zero? = base_price_zero?(package_changeset)

    ~H"""
    <.form for={@package_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <h2 class="text-xl font-bold">Package Details</h2>
      <.package_basic_fields form={f} job_type={@job_type} />

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

      <.footer>
        <button class="px-8 btn-primary" title="Next" type="submit" disabled={Enum.any?([@download_changeset, @package_pricing_changeset, @package_changeset], &(!&1.valid?))} phx-disable-with="Next">
          Next
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>Go back</button>
      </.footer>
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
      <.footer>
        <button class="px-8 btn-primary" title="Next" type="submit" disabled={if remaining_amount_zero?, do: false, else: !@payments_changeset.valid?} phx-disable-with="Next">
          Next
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>Go back</button>
      </.footer>
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
        "submit",
        %{"client" => %{"type" => type} = params},
        %{assigns: %{step: :add_client, changeset: changeset}} = socket
      ) do
    case changeset do
      %{valid?: true} ->
        socket
        |> assign(
          step: :package_payment,
          job_type: type
        )
        |> assign_job_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"client" => params},
        %{assigns: %{step: :add_client}} = socket
      ) do
    case save_client(params, socket) do
      {:ok, client} ->
        send(socket.parent_pid, {:update, client})
        socket |> close_modal() |> redirect(to: "/clients/#{client.id}") |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event(
        "toggle-pre-picsello",
        %{},
        %{assigns: %{pre_picsello_client: pre_picsello_client}} = socket
      ) do
    socket
    |> assign(:pre_picsello_client, !pre_picsello_client)
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :invoice}} = socket),
    do: socket |> assign(:step, :documents) |> noreply()

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :documents}} = socket),
    do: import_job(socket)

  @impl true
  def handle_event("validate", %{"client" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
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
        "save",
        %{"client" => params},
        socket
      ) do
    case save_client(params, socket) do
      {:ok, client} ->
        send(socket.parent_pid, {:update, client})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
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
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.ImportWizard

  defp save_client(params, %{assigns: %{current_user: current_user, client: nil}}) do
    Clients.save_new_client(params, current_user.organization_id)
  end

  defp save_client(params, %{assigns: %{client: client}}) do
    Clients.update_client(client, params)
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user, client: nil}},
         params
       ) do
    Clients.new_client_changeset(params, current_user.organization_id)
  end

  defp build_changeset(%{assigns: %{client: client}}, params) do
    Clients.edit_client_changeset(client, params)
  end

  defp assign_changeset(socket, action \\ nil, params \\ %{})

  defp assign_changeset(socket, :validate, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_changeset(socket, action, params) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def open(%{assigns: %{current_user: current_user}} = socket, client \\ nil) do
    socket |> open_modal(__MODULE__, %{current_user: current_user, client: client})
  end

  defp import_job(socket) do
    case insert_multi(socket) do
      {:ok, %{job: job, client: %Client{id: client_id}}} ->
        upload_docs(job, socket)

        socket |> push_redirect(to: Routes.client_path(socket, :job_history, client_id))

      {:error, _} ->
        socket
    end
    |> noreply()
  end

  defp insert_multi(
         %{
           assigns:
             %{
               changeset: changeset,
               job_changeset: job_changeset,
               package_changeset: package_changeset
             } = _assigns
         } = socket
       ) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:client, changeset |> Map.put(:action, nil))
    |> Ecto.Multi.insert(:job, fn changes ->
      job_changeset
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

  defp assign_job_types(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    socket
    |> assign_new(:job_types, fn ->
      (organization.profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq()
    end)
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

  defp assign_job_changeset(
         socket,
         params,
         action \\ nil
       ) do
    changeset =
      params
      |> Job.create_changeset()
      |> Map.put(:action, action)

    assign(socket, job_changeset: changeset)
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
