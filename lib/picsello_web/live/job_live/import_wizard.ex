defmodule PicselloWeb.JobLive.ImportWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Job, Package, Packages.Download, Packages.PackagePricing, Repo, BookingProposal}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.JobLive.Shared, only: [job_form_fields: 1]

  import PicselloWeb.PackageLive.Shared,
    only: [package_basic_fields: 1, digital_download_fields: 1, current: 1]

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
      |> Picsello.Package.validate_money(:price, greater_than: 0)
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
      remaining = PicselloWeb.JobLive.ImportWizard.remaining_to_collect(changeset)

      if Money.zero?(remaining) do
        changeset
      else
        add_error(changeset, :remaining_price, "is not valid")
      end
    end
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> assign(
      step: :get_started,
      steps: [:get_started, :job_details, :package_payment, :invoice]
    )
    |> assign_job_changeset(%{"client" => %{}})
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
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
    <div {testid("import-job-card")} class="flex overflow-hidden border border-base-200 rounded-lg mt-8">
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

  def step(%{step: :package_payment} = assigns) do
    ~H"""
    <.form for={@package_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <h2 class="text-xl font-bold">Package Details</h2>
      <.package_basic_fields form={f} />

      <hr class="mt-8 border-gray-100">

      <h2 class="mt-4 mb-2 text-xl font-bold">Package Base Price</h2>
      <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <label for={input_id(f, :base_price)}>
          The amount you’ve charged for your job <p>(including download credits)</p>
        </label>
        <div class="w-full sm:w-auto flex items-center justify-end mt-6">
          <span class="text-base-250 font-bold text-2xl mx-3">+</span>
          <%= input f, :base_price, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg sm:mt-0 text-center", phx_hook: "PriceMask" %>
        </div>
      </div>
      <div class="mt-4 flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <label for={input_id(f, :print_credits)}>
          How much of the creative session fee is for print credits?
        </label>
        <%= input f, :print_credits, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg mt-6 sm:mt-0 text-center", phx_hook: "PriceMask" %>
      </div>

      <hr class="mt-4 border-gray-100">

      <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <label for={input_id(f, :collected_price)}>
          The amount you’ve already collected
        </label>
        <div class="w-full sm:w-auto flex items-center justify-end mt-6">
          <span class="text-base-250 font-bold text-2xl mx-3">-</span>
          <%= input f, :collected_price, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg sm:mt-0 text-center", phx_hook: "PriceMask" %>
        </div>
      </div>

      <dl class="flex justify-between mt-4 font-bold text-lg">
        <dt>Remaining balance to collect with Picsello</dt>
        <dd class="sm:w-32 w-full text-center text-green-finances-300"><%= total_remaining_amount(@package_changeset) %></dd>
      </dl>

      <hr class="mt-4 border-gray-100">

      <.digital_download_fields package_form={f} download={@download_changeset} package_pricing={@package_pricing_changeset} />

      <.footer>
        <button class="btn-primary px-8" title="Next" type="submit" disabled={Enum.any?([@download_changeset, @package_pricing_changeset, @package_changeset], &(!&1.valid?))} phx-disable-with="Next">
          <%= if need_to_specify_payments?(@package_changeset), do: "Next", else: "Save" %>
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>
          Go back
        </button>
      </.footer>
    </.form>
    """
  end

  def step(%{step: :invoice} = assigns) do
    ~H"""
    <.form for={@payments_changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
      <h3 class="font-bold">Balance to collect: <%= total_remaining_amount(@package_changeset) %></h3>

      <%= inputs_for f, :payment_schedules, fn p -> %>
        <div {testid("payment-#{p.index + 1}")}>
          <div class="mt-4 flex items-center">
            <div class="mb-2 text-xl font-bold">Payment <%= p.index + 1 %></div>

            <%= if p.index > 0 do %>
              <.icon_button class="ml-8" title="remove" phx-click="remove-payment" phx-target={@myself} color="red-sales-300" icon="trash">
                Remove
              </.icon_button>
            <% end %>
          </div>

          <div class="flex flex-wrap mb-8 w-full">
            <div class="w-full sm:w-auto">
              <%= labeled_input p, :due_date, label: "Due", type: :date_input, placeholder: "mm/dd/yyyy", class: "sm:w-64 w-full px-4 text-lg" %>
            </div>
            <div class="sm:ml-16 w-full sm:w-auto">
              <%= labeled_input p, :price, label: "Payment amount", placeholder: "$0.00", class: "sm:w-36 w-full px-4 text-lg text-center", phx_hook: "PriceMask" %>
            </div>
          </div>
        </div>
      <% end %>

      <%= if f |> current() |> Map.get(:payment_schedules) |> Enum.count == 1 do %>
        <button type="button" title="add" phx-click="add-payment" phx-target={@myself} class="btn-secondary px-2 py-1 mb-8">
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
      <p class="italic font-light text-sm mb-2">limit two payments</p>

      <.footer>
        <button class="btn-primary px-8" title="Next" type="submit" disabled={!@payments_changeset.valid?} phx-disable-with="Next">
          Save
        </button>
        <button class="btn-secondary" title="cancel" type="button" phx-click="back" phx-target={@myself}>
          Go back
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
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_job_changeset(params, :validate) |> noreply()
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
  def handle_event("submit", %{"job" => params}, %{assigns: %{step: :job_details}} = socket) do
    case socket |> assign_job_changeset(params, :validate) do
      %{assigns: %{job_changeset: %{valid?: true}}} ->
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
        if need_to_specify_payments?(package_changeset) do
          socket
          |> assign(
            step: :invoice,
            payments_changeset:
              payments_changeset
              |> Ecto.Changeset.put_change(
                :remaining_price,
                total_remaining_amount(package_changeset)
              )
          )
          |> noreply()
        else
          import_job(socket)
        end

      socket ->
        socket
        |> noreply()
    end
  end

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :invoice}} = socket) do
    import_job(socket)
  end

  defp import_job(%{assigns: assigns} = socket) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:job, assigns.job_changeset |> Map.put(:action, nil))
      |> Ecto.Multi.insert(:package, assigns.package_changeset |> Map.put(:action, nil))
      |> Ecto.Multi.update(:job_update, fn changes ->
        Job.add_package_changeset(changes.job, %{package_id: changes.package.id})
      end)
      |> Ecto.Multi.insert(:proposal, fn changes ->
        BookingProposal.create_changeset(%{job_id: changes.job.id})
      end)
      |> maybe_insert_payment_schedules(socket)
      |> Repo.transaction()

    case result do
      {:ok, %{job: %Job{id: job_id}}} ->
        socket |> push_redirect(to: Routes.job_path(socket, :jobs, job_id)) |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  defp maybe_insert_payment_schedules(multi_changes, %{assigns: assigns}) do
    if need_to_specify_payments?(assigns.package_changeset) do
      multi_changes
      |> Ecto.Multi.insert_all(:payment_schedules, Picsello.PaymentSchedule, fn changes ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        assigns.payments_changeset
        |> current()
        |> Map.get(:payment_schedules)
        |> Enum.with_index()
        |> Enum.map(fn {payment_schedule, i} ->
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
      end)
    else
      multi_changes
    end
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
        "organization_id" => current_user.organization_id
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

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defp total_remaining_amount(package_changeset) do
    base_price = Ecto.Changeset.get_field(package_changeset, :base_price) || Money.new(0)

    collected_price =
      Ecto.Changeset.get_field(package_changeset, :collected_price) || Money.new(0)

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

  defp need_to_specify_payments?(package_changeset) do
    !(package_changeset |> total_remaining_amount() |> Money.zero?())
  end
end
