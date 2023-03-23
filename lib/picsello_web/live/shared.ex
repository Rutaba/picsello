defmodule PicselloWeb.Live.Shared do
  use Phoenix.{HTML, Component}

  import PicselloWeb.LiveHelpers
  import PicselloWeb.FormHelpers
  import Phoenix.HTML.Form

  import PicselloWeb.LiveModal, only: [footer: 1]

  import PicselloWeb.PackageLive.Shared,
    only: [package_basic_fields: 1, digital_download_fields: 1, current: 1]

  import PicselloWeb.JobLive.Shared,
    only: [
      drag_drop: 1,
      files_to_upload: 1,
      error_action: 1,
      renew_uploads: 3
    ]

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Query}
  alias PicselloWeb.Shared.ConfirmationComponent

  alias Picsello.{
    Job,
    Jobs,
    Client,
    Package,
    Repo,
    BookingProposal,
    Workers.CleanStore,
    Packages.Download,
    Packages.PackagePricing
  }

  alias PicselloWeb.Live.Shared.CustomPayments
  alias PicselloWeb.Router.Helpers, as: Routes

  defmodule CustomPaymentSchedule do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :price, Money.Ecto.Amount.Type
      field :due_date, :date
    end

    def changeset(payment_schedule, attrs \\ %{}) do
      payment_schedule
      |> cast(attrs, [:price, :due_date])
      |> validate_required([:price, :due_date])
      |> Package.validate_money(:price, greater_than: 0)
    end
  end

  defmodule CustomPayments do
    @moduledoc "For setting payments on last step"
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:remaining_price, Money.Ecto.Amount.Type)
      embeds_many(:payment_schedules, CustomPaymentSchedule)
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:remaining_price])
      |> cast_embed(:payment_schedules)
      |> validate_total_amount()
    end

    defp validate_total_amount(changeset) do
      remaining = PicselloWeb.Live.Shared.remaining_to_collect(changeset)

      if Money.zero?(remaining) do
        changeset
      else
        add_error(changeset, :remaining_price, "is not valid")
      end
    end
  end

  defmodule CustomPagination do
    @moduledoc "For setting custom pagination using limit and offset"
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:first_index, :integer, default: 1)
      field(:last_index, :integer, default: 0)
      field(:total_count, :integer, default: 0)
      field(:limit, :integer, default: 12)
      field(:offset, :integer, default: 0)
    end

    @attrs [:first_index, :last_index, :total_count, :limit, :offset]
    def changeset(struct, attrs \\ %{}) do
      struct
      |> cast(attrs, @attrs)
    end

    def assign_pagination(socket, default_limit),
      do:
        socket
        |> assign_new(:pagination_changeset, fn ->
          changeset(%__MODULE__{}, %{limit: default_limit})
        end)

    def update_pagination(
          %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
          %{"direction" => direction}
        ) do
      pagination = pagination_changeset |> Changeset.apply_changes()

      updated_pagination =
        case direction do
          "back" ->
            pagination
            |> changeset(%{
              first_index: pagination.first_index - pagination.limit,
              offset: pagination.offset - pagination.limit
            })

          _ ->
            pagination
            |> changeset(%{
              first_index: pagination.first_index + pagination.limit,
              offset: pagination.offset + pagination.limit
            })
        end

      socket
      |> assign(:pagination_changeset, updated_pagination)
    end

    def update_pagination(
          %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
          %{"custom_pagination" => %{"limit" => limit}}
        ) do
      limit = to_integer(limit)

      updated_pagination_changeset =
        pagination_changeset
        |> changeset(%{
          limit: limit,
          last_index: limit,
          total_count: pagination_changeset |> current() |> Map.get(:total_count)
        })

      socket
      |> assign(:pagination_changeset, updated_pagination_changeset)
    end

    def reset_pagination(
          %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
          params
        ),
        do:
          socket
          |> assign(
            :pagination_changeset,
            changeset(pagination_changeset |> Changeset.apply_changes(), params)
          )

    def pagination_index(changeset, index),
      do: changeset |> current() |> Map.get(index)
  end

  def step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  def total_remaining_amount(package_changeset) do
    base_price = Changeset.get_field(package_changeset, :base_price) || Money.new(0)

    collected_price = Changeset.get_field(package_changeset, :collected_price) || Money.new(0)

    base_price |> Money.subtract(collected_price)
  end

  def remaining_to_collect(payments_changeset) do
    %{
      remaining_price: remaining_price,
      payment_schedules: payments
    } = payments_changeset |> current()

    total_collected =
      payments
      |> Enum.reduce(Money.new(0), fn payment, acc ->
        Money.add(acc, payment.price || Money.new(0))
      end)

    Money.subtract(remaining_price, total_collected)
  end

  def remaining_amount_zero?(package_changeset),
    do: package_changeset |> total_remaining_amount() |> Money.zero?()

  def base_price_zero?(package_changeset),
    do: (Changeset.get_field(package_changeset, :base_price) || Money.new(0)) |> Money.zero?()

  def maybe_insert_payment_schedules(multi_changes, %{assigns: assigns}) do
    if remaining_amount_zero?(assigns.package_changeset) do
      multi_changes
    else
      multi_changes
      |> Ecto.Multi.insert_all(:payment_schedules, Picsello.PaymentSchedule, fn changes ->
        assigns.payments_changeset
        |> current()
        |> Map.get(:payment_schedules)
        |> Enum.with_index()
        |> make_payment_schedule(changes)
      end)
    end
  end

  defp make_payment_schedule(multi_changes, changes) do
    multi_changes
    |> Enum.map(fn {payment_schedule, i} ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, due_at} =
        payment_schedule.due_date
        |> DateTime.new(~T[00:00:00])

      %{
        price: payment_schedule.price,
        due_at: due_at,
        job_id: changes.job.id,
        inserted_at: now,
        updated_at: now,
        description: "Payment #{i + 1}"
      }
    end)
  end

  def heading_subtitle(step) do
    Map.get(
      %{
        get_started: "Get Started",
        add_client: "General Details",
        job_details: "General Details",
        package_payment: "Package & Payment",
        invoice: "Custom Invoice",
        documents: "Documents (optional)"
      },
      step
    )
  end

  def make_popup(socket, opts) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: opts[:close_label] || "No, go back",
      confirm_event: opts[:event],
      class: "dialog-photographer",
      confirm_class: Keyword.get(opts, :confirm_class, "btn-warning"),
      confirm_label: Keyword.get(opts, :confirm_label, "Yes, delete"),
      icon: Keyword.get(opts, :icon, "warning-orange"),
      title: opts[:title],
      subtitle: opts[:subtitle],
      dropdown?: opts[:dropdown?],
      dropdown_label: opts[:dropdown_label],
      dropdown_items: opts[:dropdown_items],
      payload: Keyword.get(opts, :payload, %{})
    })
    |> noreply()
    end

  def package_payment_step(%{package_changeset: package_changeset} = assigns) do
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

      <.digital_download_fields package_form={f} download_changeset={@download_changeset} package_pricing={@package_pricing_changeset} />

      <.footer>
        <button class="px-8 btn-primary" title="Next" type="submit" disabled={Enum.any?([@download_changeset, @package_pricing_changeset, @package_changeset], &(!&1.valid?))} phx-disable-with="Next">
          Next
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>Go back</button>
      </.footer>
    </.form>
    """
  end

  def invoice_step(%{package_changeset: package_changeset} = assigns) do
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

  def documents_step(assigns) do
    ~H"""
    <form phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-#{@step}"}>
      <.drag_drop upload_entity={@uploads.documents} supported_types=".PDF, .docx, .txt" />
      <div class={classes("uploadingList__wrapper mt-8", %{"hidden" => Enum.empty?(@uploads.documents.entries ++ @ex_documents ++ @invalid_entries)})}>
        <div class="grid grid-cols-5 pb-4 items-center text-lg font-bold" id="import_job_resume_upload" phx-hook="ResumeUpload">
          <span class="col-span-2">Name</span>
          <span class="col-span-2">Status</span>
          <span class="ml-auto">Actions</span>
        </div>
        <hr class="md:block border-blue-planning-300 border-2 mb-2">
        <%= Enum.map(@invalid_entries, fn entry -> %>
          <.files_to_upload myself={@myself} entry={entry} for={:job}>
            <.error_action error={@invalid_entries_errors[entry.ref]} entry={entry} target={@myself} />
          </.files_to_upload>
        <% end) %>
        <%= Enum.map(@uploads.documents.entries ++ @ex_documents, fn entry -> %>
          <.files_to_upload myself={@myself} entry={entry} for={:job}>
            <p class="btn items-center"><%= if entry.done?, do: "Uploaded", else: "Uploading..." %></p>
          </.files_to_upload>
        <% end) %>
      </div>

      <div class="pt-40"></div>

      <div {testid("modal-buttons")} class="sticky px-4 -m-4 bg-white -bottom-6 sm:px-8 sm:-m-8 sm:-bottom-8">
        <div class="flex flex-col py-6 bg-white gap-2 sm:flex-row-reverse">
          <button class="px-8 btn-primary" title="Finish" type="submit" disabled={Enum.any?(@invalid_entries)} phx-disable-with="Finish">
            Finish
          </button>
          <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>Go back</button>
          <a {testid("import-another-job-link")} class="z-100 flex items-center underline mr-5 cursor-pointer text-blue-planning-300 justify-center" phx-click="start_another_job" phx-target={@myself}>
            <.icon name="refresh-icon" class="h-4 w-4 mr-2 text-blue-planning-300"></.icon>
            <%= "Start another job import for #{cond do
              @searched_client -> @searched_client.name
              @selected_client -> @selected_client.name
              @client_name -> @client_name
              true -> Changeset.get_field(@job_changeset.changes.client, :name)
            end}" %>
          </a>
        </div>
      </div>
    </form>
    """
  end

  def client_name_box(%{assigns: %{job_changeset: job_changeset}} = assigns) do
    assigns = assigns |> Enum.into(%{changeset: nil})

    ~H"""
      <div class="flex items-center hover:cursor-auto mt-2">
        <div class="ml-3 mr-3 text-base-200 hidden md:block">|</div>
        <.icon name="client-icon" class="w-7 h-7 mr-1 text-blue-planning-300"></.icon>
        <p class="font-bold">
          Client: <span class="font-normal"><%=
            cond do
              @changeset -> Changeset.get_field(@changeset, :name)
              @searched_client -> @searched_client.name
              @selected_client -> @selected_client.name
              true -> Changeset.get_field(job_changeset.changes.client, :name)
            end
          %></span>
        </p>
      </div>
    """
  end

  def go_back_event(
        "back",
        %{},
        %{assigns: %{step: step, steps: steps}} = socket
      ) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(
      step:
        if(previous_step == :get_started,
          do: step,
          else: previous_step
        )
    )
  end

  def go_back_event(
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
  end

  def remove_payment_event(
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
  end

  def add_payment_event(
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
  end

  def invoice_submit_event("submit", %{}, %{assigns: %{step: :invoice}} = socket),
    do: socket |> assign(:step, :documents)

  def payment_package_submit_event(
        "submit",
        params,
        %{assigns: %{step: :package_payment}} = socket
      ) do
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

      socket ->
        socket
    end
  end

  def validate_package_event("validate", %{"package" => _} = params, socket),
    do: socket |> assign_package_changeset(params, :validate)

  def validate_payments_event("validate", %{"custom_payments" => params}, socket),
    do: socket |> assign_payments_changeset(params, :validate)

  def assign_payments_changeset(
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

  def assign_package_changeset(
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

  def import_job_for_import_wizard(
        %{
          assigns: %{
            selected_client: selected_client,
            searched_client: searched_client,
            job_changeset: job_changeset
          }
        } = socket
      ) do
    job = job_changeset |> Changeset.apply_changes()
    client = get_client(selected_client, searched_client, job.client)
    job_changeset = job_changeset |> Changeset.delete_change(:client)

    socket
    |> save_multi(client, job_changeset, "import_wizard")
  end

  def import_job_for_form_component(
        %{assigns: %{changeset: changeset, job_changeset: job_changeset}} = socket
      ) do
    client = %Client{
      name: Changeset.get_field(changeset, :name),
      email: Changeset.get_field(changeset, :email)
    }

    socket
    |> save_multi(client, job_changeset, "form_component")
  end

  defp save_multi(
         %{
           assigns: %{
             current_user: current_user,
             package_changeset: package_changeset,
             ex_documents: ex_documents,
             another_import: another_import
           }
         } = socket,
         client,
         job_changeset,
         type
       ) do
    Multi.new()
    |> Jobs.maybe_upsert_client(client, current_user)
    |> Multi.insert(:job, fn changes ->
      job_changeset
      |> Changeset.put_change(:client_id, changes.client.id)
      |> Job.document_changeset(%{
        documents: Enum.map(ex_documents, &%{name: &1.client_name, url: &1.path})
      })
      |> Map.put(:action, nil)
    end)
    |> Multi.run(:cancel_oban_jobs, fn _repo, _ ->
      Oban.Job
      |> Query.where(worker: "Picsello.Workers.CleanStore")
      |> Query.where([oban], oban.id in ^Enum.map(ex_documents, & &1.oban_job_id))
      |> Oban.cancel_all_jobs()
    end)
    |> Multi.insert(:package, package_changeset |> Map.put(:action, nil))
    |> Multi.update(:job_update, fn changes ->
      Job.add_package_changeset(changes.job, %{package_id: changes.package.id})
    end)
    |> Multi.insert(:proposal, fn changes ->
      BookingProposal.create_changeset(%{job_id: changes.job.id})
    end)
    |> maybe_insert_payment_schedules(socket)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{job: job}} ->
        if(another_import,
          do:
            socket
            |> assign(:another_import, false)
            |> assign(:ex_documents, [])
            |> assign(
              if(type == "import_wizard",
                do: %{step: :job_details},
                else: %{step: :package_payment}
              )
            )
            |> assign_package_changeset(%{})
            |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]}),
          else:
            socket |> push_redirect(to: Routes.client_path(socket, :job_history, job.client_id))
        )

      {:error, _} ->
        socket
    end)
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

  @scheduled_at_hours 2
  def handle_progress(
        :documents,
        entry,
        %{assigns: %{ex_documents: ex_documents, uploads: %{documents: %{entries: entries}}}} =
          socket
      ) do
    if entry.done? do
      key = Job.document_path(entry.client_name, entry.uuid)
      opts = [scheduled_at: Timex.now() |> Timex.shift(hours: @scheduled_at_hours)]
      oban_job = CleanStore.new(%{path: key}, opts) |> Oban.insert!()
      new_entry = Map.put(entry, :path, key) |> Map.put(:oban_job_id, oban_job.id)

      entries
      |> Enum.reject(&(&1.uuid == entry.uuid))
      |> renew_uploads(entry, socket)
      |> assign(:ex_documents, [new_entry | ex_documents])
      |> noreply()
    else
      socket |> noreply()
    end
  end
end
