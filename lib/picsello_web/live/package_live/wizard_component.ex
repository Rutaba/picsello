defmodule PicselloWeb.PackageLive.WizardComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  alias Ecto.Changeset

  alias Picsello.{
    Repo,
    Package,
    Packages,
    Packages.Multiplier,
    Packages.Download,
    Packages.PackagePricing,
    Contracts,
    Contract,
    PackagePaymentSchedule,
    PackagePayments,
    Shoot,
    Questionnaire
  }

  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]

  import PicselloWeb.PackageLive.Shared,
    only: [
      package_card: 1,
      package_basic_fields: 1,
      digital_download_fields: 1,
      print_credit_fields: 1,
      current: 1
    ]

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @all_fields Package.__schema__(:fields)
  @payment_defaults_fixed %{
    "wedding" => ["To Book", "6 Months Before", "Week Before"],
    "family" => ["To Book", "Day Before Shoot"],
    "maternity" => ["To Book", "Day Before Shoot"],
    "newborn" => ["To Book", "Day Before Shoot"],
    "event" => ["To Book", "Day Before Shoot"],
    "headshot" => ["To Book"],
    "portrait" => ["To Book"],
    "mini" => ["To Book"],
    "boudoir" => ["To Book", "Day Before Shoot"],
    "other" => ["To Book", "Day Before Shoot"],
    "payment_due_book" => ["To Book"],
    "splits_2" => ["To Book", "Day Before Shoot"],
    "splits_3" => ["To Book", "6 Months Before", "Week Before"]
  }

  defmodule CustomPayments do
    @moduledoc "For setting payments on last step"
    use Ecto.Schema
    import Ecto.Changeset

    @future_date ~U[3022-01-01 00:00:00Z]

    @primary_key false
    embedded_schema do
      field(:schedule_type, :string)
      field(:fixed, :boolean)
      field(:total_price, Money.Ecto.Amount.Type)
      field(:remaining_price, Money.Ecto.Amount.Type)
      embeds_many(:payment_schedules, PackagePaymentSchedule)
    end

    def changeset(attrs, default_payment_changeset \\ nil) do
      fixed = %__MODULE__{} |> cast(attrs, [:fixed]) |> Changeset.get_field(:fixed)

      %__MODULE__{}
      |> cast(attrs, [:total_price, :remaining_price, :fixed, :schedule_type])
      |> cast_embed(:payment_schedules,
        with: &PackagePaymentSchedule.changeset(&1, &2, default_payment_changeset, fixed),
        required: true
      )
      |> validate_schedule_date(default_payment_changeset)
      |> validate_required([:schedule_type, :fixed])
      |> validate_total_amount()
    end

    defp validate_schedule_date(changeset, default_payment_changeset) do
      {schedules_changeset, _} =
        changeset
        |> Changeset.get_change(:payment_schedules)
        |> Enum.reduce({[], []}, fn payment, {schedules, acc} ->
          payment = transform_to_schedule_date(payment, default_payment_changeset)

          schedules_changeset =
            if Enum.any?(acc) do
              Enum.with_index(acc, fn x_schedule_date, index ->
                compare_and_validate(payment, x_schedule_date, index, length(acc))
              end)
              |> List.flatten()
              |> List.first()
              |> then(fn
                nil -> schedules ++ [payment]
                schedule -> schedules ++ [schedule]
              end)
            else
              schedules ++ [payment]
            end

          schedule_date = Changeset.get_field(payment, :schedule_date)
          {schedules_changeset, if(schedule_date, do: acc ++ [schedule_date], else: acc)}
        end)

      Changeset.put_change(changeset, :payment_schedules, schedules_changeset |> List.flatten())
    end

    defp compare_and_validate(changeset, x_schedule_date, index, field_index) do
      case Date.compare(Changeset.get_field(changeset, :schedule_date), x_schedule_date) do
        :lt ->
          add_error(
            changeset,
            :schedule_date,
            "Payment #{field_index + 1} must be after Payment #{index + 1}"
          )

        :eq ->
          add_error(
            changeset,
            :schedule_date,
            "Payment #{field_index + 1} and Payment #{index + 1} can't be same"
          )

        _ ->
          []
      end
    end

    defp validate_total_amount(changeset) do
      remaining = remaining_to_collect(changeset)

      if Money.zero?(remaining) do
        changeset
      else
        changeset
        |> add_error(:remaining_price, "is not valid")
      end
      |> Changeset.put_change(:remaining_price, remaining)
    end

    defp remaining_to_collect(payments_changeset) do
      %{
        fixed: fixed,
        total_price: total_price,
        payment_schedules: payments
      } = payments_changeset |> current()

      total_collected =
        payments
        |> Enum.reduce(Money.new(0), fn payment, acc ->
          if fixed do
            Money.add(acc, payment.price || Money.new(0))
          else
            Money.add(acc, from_percentage(payment.percentage, total_price))
          end
        end)

      Money.subtract(total_price, total_collected.amount)
    end

    defp from_percentage(nil, _), do: Money.new(0)

    defp from_percentage(price, total_price) do
      Money.divide(total_price, 100) |> List.first() |> Money.multiply(price)
    end

    defp transform_to_schedule_date(changeset, default_payment_changeset) do
      shoot_date = get_shoot_date(Changeset.get_field(changeset, :shoot_date))

      schedule_date =
        case Changeset.get_field(changeset, :interval) do
          true ->
            transform_text_to_date(Changeset.get_field(changeset, :due_interval), shoot_date)

          _ ->
            transform_text_to_date(changeset, default_payment_changeset, shoot_date)
        end

      Changeset.put_change(changeset, :schedule_date, schedule_date)
    end

    defp transform_text_to_date("" <> due_interval, shoot_date) do
      cond do
        String.contains?(due_interval, "6 Months Before") -> Timex.shift(shoot_date, months: -6)
        String.contains?(due_interval, "1 Month Before") -> Timex.shift(shoot_date, months: -1)
        String.contains?(due_interval, "Week Before") -> Timex.shift(shoot_date, days: -7)
        String.contains?(due_interval, "Day Before") -> Timex.shift(shoot_date, days: -1)
        true -> Timex.now() |> DateTime.truncate(:second)
      end
    end

    defp transform_text_to_date(changeset, default_payment_changeset, shoot_date) do
      interval =
        if default_payment_changeset,
          do:
            PackagePaymentSchedule.get_default_payment_schedules_values(
              default_payment_changeset,
              :interval,
              get_field(changeset, :payment_field_index)
            ),
          else: false

      due_at = Changeset.get_field(changeset, :due_at)

      if due_at || (Changeset.get_field(changeset, :shoot_date) && interval) do
        if due_at, do: due_at |> Timex.to_datetime(), else: shoot_date
      else
        last_shoot_date = get_shoot_date(Changeset.get_field(changeset, :last_shoot_date))
        count_interval = Changeset.get_field(changeset, :count_interval)
        count_interval = if count_interval, do: count_interval |> String.to_integer(), else: 1
        time_interval = Changeset.get_field(changeset, :time_interval)

        time_interval =
          if(time_interval, do: time_interval <> "s", else: "Days")
          |> String.downcase()
          |> String.to_atom()

        if(Changeset.get_field(changeset, :shoot_interval) == "Before 1st Shoot",
          do: Timex.shift(shoot_date, [{time_interval, -count_interval}]),
          else: Timex.shift(last_shoot_date, [{time_interval, -count_interval}])
        )
      end
    end

    defp get_shoot_date(shoot_date), do: if(shoot_date, do: shoot_date, else: @future_date)
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1, contract: nil} end)
    |> assign_new(:package_pricing, fn -> %PackagePricing{} end)
    |> assign_new(:contract_changeset, fn -> nil end)
    |> assign_new(:collapsed_documents, fn -> [0, 1] end)
    |> assign(is_template: assigns |> Map.get(:job) |> is_nil(), job_types: Packages.job_types())
    |> choose_initial_step()
    |> assign_changeset(%{})
    |> assign_questionnaires()
    |> assign(default: %{})
    |> assign(custom: false)
    |> assign(job_type: nil)
    |> assign(custom_schedule_type: nil)
    |> assign(default_payment_changeset: nil)
    |> ok()
  end

  defp assign_payments_changeset(
         %{assigns: %{default_payment_changeset: default_payment_changeset}} = socket,
         params,
         action
       ) do
    changeset =
      params |> CustomPayments.changeset(default_payment_changeset) |> Map.put(:action, action)

    assign(socket, payments_changeset: changeset)
  end

  defp remaining_price(changeset),
    do:
      Changeset.get_field(changeset, :base_price)
      |> Money.multiply(Changeset.get_field(changeset, :base_multiplier))

  defp choose_initial_step(%{assigns: %{is_template: true}} = socket) do
    socket
    |> assign(templates: [], step: :details, steps: [:details, :documents, :pricing, :payment])
  end

  defp choose_initial_step(%{assigns: %{current_user: user, job: job, package: package}} = socket) do
    with %{type: job_type} <- job,
         %{id: nil} <- package,
         templates when templates != [] <- Packages.templates_for_user(user, job_type) do
      socket
      |> assign(
        templates: templates,
        step: :choose_template,
        steps: [:choose_template, :details, :pricing, :payment]
      )
    else
      _ -> socket |> assign(templates: [], step: :details, steps: [:details, :pricing, :payment])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <.steps step={@step} steps={@steps} target={@myself} />
      <.step_heading name={@step} is_edit={@package.id} />

      <.form for={@changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <input type="hidden" name="step" value={@step} />

        <.wizard_state form={f} contract_changeset={@contract_changeset} />

        <.step name={@step} f={f} {assigns} />

        <.footer class="pt-10">
          <.step_buttons name={@step} form={f} is_valid={step_valid?(assigns)} myself={@myself} />

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  defp step_valid?(%{step: :payment, payments_changeset: payments_changeset}),
    do: payments_changeset.valid?

  defp step_valid?(%{step: :documents, contract_changeset: contract}), do: contract.valid?

  defp step_valid?(assigns),
    do:
      Enum.all?(
        [assigns.download, assigns.package_pricing, assigns.multiplier, assigns.changeset],
        & &1.valid?
      )

  def wizard_state(assigns) do
    fields = @all_fields

    ~H"""
      <%= for field <- fields, input_value(@form, field) do %>
        <%= hidden_input @form, field, id: nil %>
      <% end %>

      <% c = form_for(@contract_changeset, "#") %>
      <%= for field <- [:name, :content, :contract_template_id, :edited], input_value(c, field) do %>
        <%= hidden_input c, field, id: nil %>
      <% end %>
    """
  end

  def step_heading(%{name: :choose_template} = assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl font-bold">Package Templates</h1>
    """
  end

  def step_heading(assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl"><strong class="font-bold"><%= heading_title(@is_edit) %>:</strong> <%= heading_subtitle(@name) %></h1>
    """
  end

  def heading_title(is_edit), do: if(is_edit, do: "Edit Package", else: "Add a Package")

  def heading_subtitle(step) do
    Map.get(
      %{
        details: "Provide Details",
        documents: "Select Documents",
        pricing: "Set Pricing"
      },
      step
    )
  end

  def step_subheading(%{name: :choose_template} = assigns) do
    ~H"""
    """
  end

  def step_subheading(assigns) do
    ~H"""
      <p>Create a new package</p>
    """
  end

  def step_buttons(%{name: :choose_template} = assigns) do
    ~H"""
    <button class="btn-primary" title="Use template" type="submit" phx-disable-with="Use Template" disabled={!template_selected?(@form)}>
      Use template
    </button>

    <%= if template_selected?(@form) do %>
      <button class="btn-secondary" title="Customize" type="button" phx-click="customize-template" phx-target={@myself}>
        Customize
      </button>
    <% else %>
      <button class="btn-primary" title="New Package" type="button" phx-click="new-package" phx-target={@myself}>
        New Package
      </button>
    <% end %>
    """
  end

  def step_buttons(%{name: step} = assigns) when step in [:details, :documents, :pricing] do
    ~H"""
    <button class="btn-primary" title="Next" type="submit" disabled={!@is_valid} phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{name: :payment} = assigns) do
    ~H"""
    <button class="px-8 mb-2 sm:mb-0 btn-primary" title="Save" type="submit" disabled={!@is_valid} phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{name: :choose_template} = assigns) do
    ~H"""
    <h1 class="mt-6 text-xl font-bold">Select Package <%= if template_selected?(@f), do: "(1 selected)", else: "" %></h1>
      <div class="grid grid-cols-1 my-4 sm:grid-cols-2 lg:grid-cols-3 gap-7">
        <%= for template <- @templates do %>
          <% checked = input_value(@f, :package_template_id) == template.id %>

          <label {testid("template-card")}>
            <input class="hidden" type="radio" name={input_name(@f, :package_template_id)} value={if checked, do: "", else: template.id} />
            <.package_card package={template} class={classes(%{"bg-blue-planning-100 border-blue-planning-300" => checked})} />
          </label>
        <% end %>
      </div>
    """
  end

  def step(%{name: :details} = assigns) do
    ~H"""
      <.package_basic_fields form={@f} job_type={if !@is_template do @job.type else "wedding" end} />

      <div class="flex flex-col mt-4">

        <.input_label form={@f} class="flex items-end justify-between mb-1 text-sm font-semibold" field={:description}>
          <span>Description <%= error_tag(@f, :description) %></span>
          <.icon_button color="red-sales-300" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(@f,:description)}>
            Clear
          </.icon_button>
        </.input_label>
        <.quill_input f={@f} html_field={:description} editor_class="min-h-[16rem]" placeholder={"Description of your#{if !@is_template do " " <> @job.type end} offering and pricing "} />
      </div>

      <hr class="mt-6" />

      <%= if @is_template do %>
        <div class="flex flex-col mt-6">
          <.input_label form={@f} class="mb-1 text-sm font-semibold" field={:job_type}>
            Type of Photography
          </.input_label>

          <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
            <%= for job_type <- @job_types do %>
              <.job_type_option type="radio" name={input_name(@f, :job_type)} job_type={job_type} checked={input_value(@f, :job_type) == job_type} />
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end

  def step(%{name: :documents} = assigns) do
    ~H"""
      <section {testid("document-contracts")} class="border border-base-200 rounded-lg mt-4 overflow-hidden">
        <div class="flex bg-base-200 px-4 py-2 items-center cursor-pointer" phx-click="toggle-collapsed-documents" phx-value-index={0} phx-target={@myself}>
          <h2 class="text-lg font-bold py-1">Add a contract</h2>
          <div class="ml-auto">
            <%= if Enum.member?(@collapsed_documents, 0) do %>
              <.icon name="down" class="w-3 h-3 stroke-current stroke-3" />
            <% else %>
              <.icon name="up" class="w-3 h-3 stroke-current stroke-3" />
            <% end %>
          </div>
        </div>
        <div class={classes("p-4", %{"hidden" => Enum.member?(@collapsed_documents, 0)})}>
          <p>Here you can copy and paste your own contract or use the legally approved contract we have developed. You're also able to version your contract for different needs if you want!</p>
          <% c = form_for(@contract_changeset, "#") %>
          <div class="grid grid-flow-col auto-cols-fr gap-4 mt-4">
            <%= labeled_select c, :contract_template_id, @contract_options, label: "Select a Contract Template" %>
            <%= labeled_input c, :name, label: "Contract Name", placeholder: "Enter new contract name", phx_debounce: "500" %>
          </div>

          <div class="flex justify-between items-end pb-2">
            <label class="block mt-4 input-label" for={input_id(c, :content)}>Contract Language</label>
            <%= cond do %>
              <% !input_value(c, :contract_template_id) -> %>
              <% input_value(c, :edited) -> %>
                <.badge color={:blue}>Edited—new template will be saved</.badge>
              <% !input_value(c, :edited) -> %>
                <.badge color={:gray}>No edits made</.badge>
            <% end %>
          </div>
          <.quill_input f={c} id="quill_contract_input" html_field={:content} enable_size={true} track_quill_source={true} placeholder="Paste contract text here" />
        </div>
      </section>
      <section {testid("document-questionnaires")} class="border border-base-200 rounded-lg mt-4 overflow-hidden">
        <div class="flex bg-base-200 px-4 py-2 items-center cursor-pointer" phx-click="toggle-collapsed-documents" phx-value-index={1} phx-target={@myself}>
          <h2 class="text-lg font-bold py-1">Add a questionnaire</h2>

          <div class="ml-auto">
            <%= if Enum.member?(@collapsed_documents, 1) do %>
              <.icon name="down" class="w-3 h-3 stroke-current stroke-3" />
            <% else %>
              <.icon name="up" class="w-3 h-3 stroke-current stroke-3" />
            <% end %>
          </div>
        </div>
        <div class={classes("p-4", %{"hidden" => Enum.member?(@collapsed_documents, 1)})}>
          <p>As with most things in Picsello, we have created a default questionnaire for you to use. If you don't select one here, we'll provide a default that you can turn off if you want when creating a lead. If you'd like to create your own template to apply to packages templates for future use, you can do so <.live_link to={Routes.questionnaires_index_path(@socket, :index)} class="underline text-blue-planning-300">here</.live_link> (modal will close and you can come back).</p>
          <%= if Enum.empty?(@questionnaires) do %>
            <p>Looks like you don't have any questionnaires. Please add one first <.live_link to={Routes.questionnaires_index_path(@socket, :index)} class="underline text-blue-planning-300">here</.live_link>. (You're modal will close and you'll have to come back)</p>
          <% else %>
            <div class="hidden sm:flex items-center justify-between border-b-8 border-blue-planning-300 font-semibold text-lg pb-6 mt-4">
              <div class="w-1/3">Questionnaire name</div>
              <div class="w-1/3 text-center"># of questions</div>
              <div class="w-1/3 text-center">Select questionnaire</div>
            </div>
            <%= for questionnaire <- @questionnaires do %>
              <div class="border p-3 sm:pt-0 sm:px-0 sm:pb-4 sm:border-b sm:border-t-0 sm:border-x-0 rounded-lg sm:rounded-none border-gray-100 mt-4">
              <label class="flex items-center justify-between cursor-pointer">
                <h3 class="font-xl font-bold w-1/3"><%= questionnaire.name %></h3>
                <p class="w-1/3 text-center"><%= questionnaire.questions |> length()  %></p>
                <div class="w-1/3 text-center">
                  <%= radio_button(@f, :questionnaire_template_id, questionnaire.id, class: "w-5 h-5 mr-2.5 radio") %>
                </div>
              </label>
              </div>
            <% end %>
          <% end %>
        </div>
      </section>
    """
  end

  def step(%{name: :pricing} = assigns) do
    ~H"""
      <div>
        <div class="bg-gray-100 mt-6 p-6 rounded-lg">
          <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
            <label for={input_id(@f, :base_price)}>
              <h2 class="mb-1 text-xl font-bold">Package Price</h2>
              Includes your Creative Session Fee, any Professional Print Credits, and/or High-Resolution Digital Images you decide to include.
            </label>

            <%= input @f, :base_price, placeholder: "$0.00", class: "sm:w-32 w-full px-4 text-lg mt-6 sm:mt-0 sm:font-normal font-bold text-center", phx_hook: "PriceMask" %>
          </div>

          <% m = form_for(@multiplier, "#") %>

          <label class="flex items-center mt-6 sm:mt-8 justify-self-start">
            <%= checkbox(m, :is_enabled, class: "w-5 h-5 mr-2 checkbox") %>

            Apply a discount or surcharge
          </label>

          <%= if m |> current() |> Map.get(:is_enabled) do %>
            <div class="flex flex-col items-center pl-0 my-6 sm:flex-row sm:pl-16">
              <h2 class="self-start mt-3 text-xl font-bold sm:self-auto sm:mt-0 justify-self-start sm:mr-4 whitespace-nowrap">Apply a</h2>

              <div class="flex w-full mt-3 sm:mt-0">
                <%= select_field(m, :percent, Multiplier.percent_options(), class: "text-left py-4 pl-4 pr-8 mr-6 sm:mr-9") %>

                <%= select_field(m, :sign, Multiplier.sign_options(), class: "text-center flex-grow sm:flex-grow-0 px-14 py-4") %>
              </div>

              <div class="self-end mt-3 sm:self-auto justify-self-end sm:mt-0">
                <%= base_adjustment(@f) %>
              </div>
            </div>
          <% end %>
        </div>

        <.print_credit_fields f={@f} package_pricing={@package_pricing} />

        <hr class="block w-full mt-6 sm:hidden"/>

        <.digital_download_fields package_form={@f} download={@download} package_pricing={@package_pricing} />
      </div>
      <dl class="flex justify-between gap-8 mt-8 bg-gray-100 p-6 rounded-lg">
        <dt class="text-xl font-bold md:ml-auto uppercase">Total</dt>
        <dd class="text-xl font-bold"><%= total_price(@f) %></dd>
      </dl>
    """
  end

  def step(
        %{
          name: :payment,
          f: %{params: params},
          default_payment_changeset: default_payment_changeset
        } = assigns
      ) do
    job_type = Map.get(params, "job_type", nil) || Map.get(assigns.job, :type, nil)

    ~H"""
    <div>
      <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <div class="mb-2">
          <h2 class="mb-1 text-xl font-bold">Payment Schedule Preset</h2>
          Use your default payment schedule or select a new one. Any changes made will result in a custom payment schedule.
        </div>
      </div>
      <% pc = form_for(@payments_changeset, "#") %>
      <div {testid("select-preset-type")} class="grid gap-6 md:grid-cols-2 grid-cols-1 mt-8">
        <%= select pc, :schedule_type, payment_dropdown_options(job_type, input_value(pc, :schedule_type)), wrapper_class: "mt-4", class: "py-3 border rounded-lg border-base-200 cursor-pointer", phx_update: "update" %>
        <div {testid("preset-summary")} class="flex items-center"><%= get_tags(pc) %></div>
      </div>
      <hr class="w-full my-6 md:my-8"/>
      <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
        <div class="mb-2">
          <h2 class="mb-1 text-xl font-bold">Payment Schedule Details</h2>
          Reminder: you're limited to three payment due dates
        </div>
      </div>
      <div class="flex flex-col items-start w-full sm:items-center sm:flex-row sm:w-auto">
        <div class="mb-8">
          <h2 class="mb-1 font-bold">Payment By:</h2>
          <div class="flex flex-col">
            <label class="my-2"><%= radio_button(pc, :fixed, true, class: "w-5 h-5 mr-2 radio cursor-pointer") %>Fixed amount</label>
            <label><%= radio_button(pc, :fixed, false, class: "w-5 h-5 mr-2 radio cursor-pointer") %>Percentage</label>
          </div>
        </div>
      </div>
      <div class="flex mb-6 md:w-1/2">
        <h2 class="font-bold">Balance to collect:</h2>
        <div {testid("balance-to-collect")} class="ml-auto"><%= total_price(@f) %> <%= unless input_value(pc, :fixed), do: "(100%)" %></div>
      </div>
      <%= hidden_input pc, :total_price %>
      <%= hidden_input pc, :remaining_price %>
      <%= inputs_for pc, :payment_schedules, fn p -> %>
        <%= hidden_input p, :shoot_date %>
        <%= hidden_input p, :last_shoot_date %>
        <%= hidden_input p, :schedule_date %>
        <%= hidden_input p, :description, value: get_tag(p, input_value(pc, :fixed)) %>
        <%= hidden_input p, :payment_field_index, value: p.index %>
        <%= hidden_input p, :fields_count, value: length(input_value(pc, :payment_schedules)) %>
        <div {testid("payment-count-card")} class="border rounded-lg border-base-200 md:w-1/2 pb-2 mt-3">
          <div class="flex items-center bg-base-200 px-2 p-2">
            <div class="mb-2 text-xl font-bold">Payment <%= p.index + 1 %></div>
              <%= if p.index != 0 do %>
                <.icon_button class="ml-auto" title="remove" phx-value-index={p.index} phx-click="remove-payment" phx-target={@myself} color="red-sales-300" icon="trash">
                  Remove
                </.icon_button>
              <% end %>
          </div>
          <h2 class="my-2 px-2 font-bold">Payment Due</h2>
          <div class="flex flex-col w-full px-2">
            <label class="items-center font-medium">
              <div class={classes("flex items-center", %{"mb-2" => is_nil(@job)})}>
                <%= radio_button(p, :interval, true, class: "w-5 h-5 mr-4 radio cursor-pointer") %>
                <span class="font-medium">At the following interval</span>
              </div>
            </label>
            <div class={classes("flex my-1 ml-8 items-center text-base-250", %{"hidden" => is_nil(@job)})}>
              <.icon name="calendar" class="w-4 h-4 mr-1 text-base-250"/>
              <%= if input_value(p, :shoot_date) |> is_value_set(), do: input_value(p, :schedule_date) |> Calendar.strftime("%m-%d-%Y"), else: "Add shoot to generate date" %>
            </div>
            <div {testid("due-interval")} class={classes("flex flex-col my-2 ml-8", %{"hidden" => !input_value(p, :interval)})}>
              <%= select p, :due_interval, interval_dropdown_options(input_value(p, :due_interval), p.index), wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
              <%= if message = p.errors[:schedule_date] do %>
                <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
              <% end %>
            </div>
            <label>
              <div class={classes("flex items-center", %{"mb-2" => input_value(p, :interval)})}>
                <%= radio_button(p, :interval, false, class: "w-5 h-5 mr-4 radio cursor-pointer") %>
                <span class="font-medium">At a custom time</span>
              </div>
            </label>
            <%= unless input_value(p, :interval) do %>
              <%= if input_value(p, :due_at) || ((input_value(p, :shoot_date) |> is_value_set()) && PackagePaymentSchedule.get_default_payment_schedules_values(default_payment_changeset, :interval, p.index)) do %>
                <div class="flex flex-col my-2 ml-8 cursor-pointer">
                  <%= input p, :due_at, type: :date_input, format: "mm/dd/yyyy", min: Date.utc_today(), placeholder: "mm/dd/yyyy", phx_debounce: "0", class: "w-full px-4 text-lg cursor-pointer" %>
                  <%= if message = p.errors[:schedule_date] do %>
                    <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                  <% end %>
                </div>
              <% else %>
                <div class="flex flex-col ml-8">
                  <div class="flex w-full my-2">
                    <div class="w-2/12">
                      <%= select p, :count_interval, 1..10, wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                    </div>
                      <div class="ml-2 w-2/5">
                      <%= select p, :time_interval, ["Day", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                    </div>
                    <div class="ml-2 w-2/3">
                      <%= select p, :shoot_interval, ["Before 1st Shoot", "Before Last Shoot"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                    </div>
                  </div>
                  <%= if message = p.errors[:schedule_date] do %>
                    <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
            <div class="flex my-2">
              <%= input p, :price, placeholder: "$0.00", class: classes("w-32 text-center p-3 border rounded-lg border-blue-planning-300 ml-auto", %{"hidden" => !input_value(pc, :fixed)}), phx_hook: "PriceMask" %>
              <%= input p, :percentage, placeholder: "0.00%", value: "#{input_value(p, :percentage)}%", class: classes("w-24 text-center p-3 border rounded-lg border-blue-planning-300 ml-auto", %{"hidden" => input_value(pc, :fixed)}), phx_hook: "PercentMask" %>
            </div>
          </div>
        </div>
      <% end %>

      <.icon_button phx-click="add-payment" phx-target={@myself} class={classes("text-sm bg-white py-1.5 shadow-lg mt-5", %{"hidden" => hide_add_button(pc)})} color="blue-planning-300" icon="plus">
        Add another payment
      </.icon_button>

      <div class="flex mb-2 md:w-1/2 mt-5">
        <h2 class="font-bold">Remaining to collect:</h2>
        <div {testid("remaining-to-collect")} class="ml-auto">
          <%= case input_value(pc, :remaining_price) do %>
            <% value -> %>
            <%= if Money.zero?(value) do %>
              <span class="text-green-finances-300"><%= get_remaining_price(input_value(pc, :fixed), value, total_price(@f)) %></span>
            <% else %>
              <span class="text-red-sales-300"><%= get_remaining_price(input_value(pc, :fixed), value, total_price(@f)) %></span>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "toggle-collapsed-documents",
        %{"index" => index},
        %{assigns: %{collapsed_documents: collapsed_documents}} = socket
      ) do
    index = String.to_integer(index)

    collapsed_documents =
      if Enum.member?(collapsed_documents, index) do
        Enum.filter(collapsed_documents, &(&1 != index))
      else
        collapsed_documents ++ [index]
      end

    socket
    |> assign(:collapsed_documents, collapsed_documents)
    |> noreply()
  end

  @impl true
  def handle_event(
        "back",
        %{},
        %{assigns: %{step: step, steps: steps}} = socket
      ) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    changeset = update_changeset(socket, step: previous_step)

    socket
    |> assign(step: previous_step, changeset: changeset)
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove-payment",
        %{"index" => index},
        %{assigns: %{payments_changeset: payments_changeset}} = socket
      ) do
    params = payments_changeset |> current() |> map_keys()

    payment_schedules =
      params
      |> Map.get("payment_schedules")
      |> List.delete_at(String.to_integer(index))
      |> map_keys()
      |> Enum.with_index(fn %{"payment_field_index" => field_index} = payment, count ->
        Map.put(payment, "payment_field_index", if(field_index, do: field_index, else: count))
      end)

    params = Map.merge(params, %{"payment_schedules" => payment_schedules})

    socket
    |> assign_payments_changeset(params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-payment",
        %{},
        %{assigns: %{job: job, payments_changeset: payments_changeset}} = socket
      ) do
    params = payments_changeset |> current() |> map_keys()
    payment_schedules = params |> Map.get("payment_schedules") |> map_keys()

    new_payment =
      if params["fixed"] do
        %{"price" => nil, "due_interval" => "Day Before Shoot"}
      else
        %{"percentage" => 34, "due_interval" => "34% Day Before"}
      end
      |> Map.merge(%{
        "shoot_date" => get_first_shoot(job),
        "last_shoot_date" => get_last_shoot(job),
        "interval" => true,
        "payment_field_index" => length(payment_schedules) - 1
      })

    params =
      Map.merge(params, %{
        "payment_schedules" =>
          payment_schedules ++ [Map.merge(payment_schedules |> List.first(), new_payment)]
      })

    socket
    |> assign_payments_changeset(params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"step" => "payment", "custom_payments" => params},
        %{assigns: %{payments_changeset: payments_changeset}} = socket
      ) do
    custom_payments_changeset =
      %CustomPayments{} |> Changeset.cast(params, [:fixed, :schedule_type])

    schedule_type = Changeset.get_field(custom_payments_changeset, :schedule_type)
    fixed = Changeset.get_field(custom_payments_changeset, :fixed)
    price = Changeset.get_field(payments_changeset, :total_price)

    cond do
      schedule_type != Changeset.get_field(payments_changeset, :schedule_type) ->
        schedule_type_switch(socket, price, schedule_type)

      fixed != Changeset.get_field(payments_changeset, :fixed) ->
        fixed_switch(socket, fixed, price, params)

      true ->
        socket |> maybe_assign_custom(params)
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"package" => %{"job_type" => _}, "_target" => ["package", "job_type"]} = params,
        socket
      ) do
    socket
    |> assign_changeset(params |> Map.drop(["contract"]), :validate)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "contract" => %{"contract_template_id" => template_id},
          "_target" => ["contract", "contract_template_id"]
        },
        %{assigns: %{changeset: changeset}} = socket
      ) do
    content =
      case template_id do
        "" ->
          ""

        id ->
          package = changeset |> current()

          package
          |> Contracts.find_by!(id)
          |> Contracts.contract_content(package, PicselloWeb.Helpers)
      end

    socket
    |> assign_contract_changeset(%{"edited" => false})
    |> push_event("quill:update", %{"html" => content})
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"contract" => contract} = params, socket) do
    contract = contract |> Map.put_new("edited", Map.get(contract, "quill_source") == "user")
    params = params |> Map.put("contract", contract)

    socket
    |> assign_changeset(params, :validate)
    |> assign_contract_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_event("validate", params, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{
          "package" => %{"package_template_id" => package_template_id},
          "step" => "choose_template"
        },
        %{assigns: %{job: job}} = socket
      ) do
    questionnaire =
      find_template(socket, package_template_id)
      |> Questionnaire.for_package()

    package_payment_schedules =
      socket
      |> find_template(package_template_id)
      |> Repo.preload(:package_payment_schedules, force: true)
      |> Map.get(:package_payment_schedules)

    changeset = changeset_from_template(socket, package_template_id)

    payment_schedules =
      package_payment_schedules
      |> Enum.map(fn schedule ->
        schedule |> Map.from_struct() |> Map.drop([:package_payment_preset_id])
      end)

    opts = %{
      payment_schedules: payment_schedules,
      action: :insert,
      questionnaire: questionnaire
    }

    insert_package_and_update_job(socket, changeset, job, opts)
  end

  @impl true
  def handle_event("submit", %{"step" => "details"} = params, socket) do
    case socket |> assign_changeset(params, :validate) do
      %{assigns: %{changeset: %{valid?: true}}} ->
        socket
        |> assign(step: next_step(socket.assigns))
        |> assign_changeset(params)
        |> assign_questionnaires(params)
        |> assign_contract_changeset(params)
        |> assign_contract_options()

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "documents"} = params, socket) do
    case socket |> assign_changeset(params, :validate) |> assign_contract_changeset(params) do
      %{assigns: %{contract_changeset: %{valid?: true}}} ->
        socket |> assign(step: :pricing) |> assign_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "pricing"} = params,
        %{
          assigns: %{
            job: job,
            package: package,
            current_user: %{organization: organization}
          }
        } = socket
      ) do
    package =
      if package.id,
        do: package |> Repo.preload(:package_payment_schedules, force: true),
        else: package

    socket
    |> assign_changeset(params)
    |> assign_contract_changeset(params)
    |> then(fn %{assigns: %{changeset: changeset}} = socket ->
      job_type = if job, do: job.type, else: changeset |> Changeset.get_field(:job_type)

      package_payment_presets =
        case package do
          %{package_payment_schedules: []} ->
            PackagePayments.get_package_presets(organization.id, job_type)

          %{package_payment_schedules: %Ecto.Association.NotLoaded{}} ->
            PackagePayments.get_package_presets(organization.id, job_type)

          _ ->
            package
        end

      socket
      |> assign(job_type: job_type)
      |> assign_payment_defaults(job_type, package_payment_presets)
    end)
    |> then(fn %{assigns: %{payments_changeset: payments_changeset}} = socket ->
      socket
      |> assign(default_payment_changeset: payments_changeset)
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "payment", "custom_payments" => payment_params},
        %{
          assigns: %{
            is_template: false,
            job: job,
            package: %Package{id: nil}
          }
        } = socket
      ) do
    questionnaire =
      socket.assigns.package
      |> Questionnaire.for_package()

    socket
    |> maybe_assign_custom(payment_params)
    |> then(fn %{assigns: %{changeset: changeset, payments_changeset: payments_changeset}} =
                 socket ->
      payment_schedules =
        payments_changeset
        |> current()
        |> Map.from_struct()
        |> Map.get(:payment_schedules, [])
        |> Enum.map(fn schedule ->
          schedule |> Map.from_struct() |> Map.drop([:package_payment_preset_id])
        end)

      total_price = Changeset.get_field(payments_changeset, :total_price)

      opts = %{
        total_price: total_price,
        payment_schedules: payment_schedules,
        action: :insert,
        questionnaire: questionnaire
      }

      insert_package_and_update_job(
        socket,
        update_package_changeset(changeset, payments_changeset),
        job,
        opts
      )
    end)
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "payment", "custom_payments" => payment_params} = params,
        %{
          assigns: %{
            is_template: true,
            current_user: %{organization: organization},
            job_type: job_type,
            package: %{id: nil}
          }
        } = socket
      ) do
    payment_preset = PackagePayments.get_package_presets(organization.id, job_type)

    socket
    |> maybe_assign_custom(payment_params)
    |> then(fn %{assigns: %{changeset: changeset, payments_changeset: payments_changeset}} =
                 socket ->
      case Packages.insert_or_update_package(
             update_package_changeset(changeset, payments_changeset),
             Map.get(params, "contract"),
             get_preset_options(payments_changeset, payment_preset)
           ) do
        {:ok, package} -> successfull_save(socket, package)
        _ -> socket |> noreply()
      end
    end)
  end

  @impl true
  def handle_event(
        "submit",
        %{"step" => "payment"} = params,
        %{assigns: %{is_template: false, job: %{id: job_id}}} = socket
      ),
      do: socket |> save_payment(params, job_id)

  @impl true
  def handle_event(
        "submit",
        %{"step" => "payment"} = params,
        %{assigns: %{is_template: true}} = socket
      ),
      do: socket |> save_payment(params)

  @impl true
  def handle_event("new-package", %{}, socket) do
    socket
    |> assign(step: :details, changeset: update_changeset(socket, step: :details))
    |> noreply()
  end

  @impl true
  def handle_event(
        "customize-template",
        %{},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    package = current(changeset)

    template =
      find_template(socket, package.package_template_id)
      |> Repo.preload(:package_payment_schedules, force: true)

    changeset = changeset_from_template(template)

    socket
    |> assign(
      step: :details,
      package:
        Map.merge(
          socket.assigns.package,
          Map.take(template, [
            :download_each_price,
            :download_count,
            :base_multiplier,
            :buy_all,
            :print_credits,
            :package_payment_schedules,
            :fixed,
            :schedule_type
          ])
        ),
      changeset: changeset
    )
    |> noreply()
  end

  defp update_package_changeset(changeset, payments_changeset) do
    payments_struct = payments_changeset |> current() |> Map.from_struct()

    changeset
    |> Changeset.put_change(:schedule_type, Map.get(payments_struct, :schedule_type))
    |> Changeset.put_change(:fixed, Map.get(payments_struct, :fixed))
  end

  defp schedule_type_switch(
         %{assigns: %{job: job, changeset: changeset}} = socket,
         price,
         schedule_type
       ) do
    fixed = schedule_type == Changeset.get_field(changeset, :job_type)
    default_presets = get_custom_payment_defaults(socket, schedule_type, fixed)

    presets =
      default_presets
      |> Enum.with_index(
        &Map.merge(
          %{
            "interval" => true,
            "shoot_date" => get_first_shoot(job),
            "last_shoot_date" => get_last_shoot(job),
            "percentage" => "",
            "due_interval" => &1
          },
          get_price_or_percentage(price, fixed, length(default_presets), &2)
        )
      )

    params = %{
      "total_price" => price,
      "remaining_price" => price,
      "payment_schedules" => presets,
      "fixed" => fixed,
      "schedule_type" => schedule_type
    }

    socket
    |> assign(default: map_default(params))
    |> assign(custom: false)
    |> assign_payments_changeset(params, :validate)
  end

  defp get_price(total_price, presets_count, index) do
    remainder = rem(total_price.amount, presets_count) * 100
    amount = if remainder == 0, do: total_price, else: Money.subtract(total_price, remainder)

    if index + 1 == presets_count do
      Money.divide(amount, presets_count) |> List.first() |> Money.add(remainder)
    else
      Money.divide(amount, presets_count) |> List.first()
    end
  end

  defp get_percentage(presets_count, index) do
    remainder = rem(100, presets_count)
    percentage = if remainder == 0, do: 100, else: 100 - remainder

    if index + 1 == presets_count do
      percentage / presets_count + remainder
    else
      percentage / presets_count
    end
    |> Kernel.trunc()
  end

  defp get_price_or_percentage(total_price, fixed, presets_count, index) do
    if fixed do
      %{"price" => get_price(total_price, presets_count, index)}
    else
      %{"percentage" => get_percentage(presets_count, index)}
    end
  end

  defp fixed_switch(socket, fixed, total_price, params) do
    {presets, _} =
      params
      |> Map.get("payment_schedules")
      |> Map.values()
      |> update_amount(fixed, total_price)

    socket
    |> maybe_assign_custom(Map.put(params, "payment_schedules", presets))
  end

  defp update_amount(schedules, fixed, total_price) do
    schedules
    |> Enum.reduce({%{}, 0}, fn schedule, {schedules, collection} ->
      schedule = Picsello.PackagePaymentSchedule.prepare_percentage(schedule)

      changeset =
        %Picsello.PackagePaymentSchedule{}
        |> Changeset.cast(schedule, [:fields_count, :payment_field_index, :price, :percentage])

      index = Changeset.get_field(changeset, :payment_field_index)
      presets_count = Changeset.get_field(changeset, :fields_count)
      price = Changeset.get_field(changeset, :price)
      percentage = Changeset.get_field(changeset, :percentage)

      if fixed do
        updated_price =
          if(price, do: price.amount / 100, else: percentage_to_price(total_price, percentage))
          |> normalize_price(collection, presets_count, index, total_price)

        {Map.merge(schedules, %{
           "#{index}" => %{schedule | "percentage" => nil, "price" => updated_price}
         }), collection + updated_price}
      else
        updated_percentage =
          if(percentage, do: percentage, else: price_to_percentage(total_price, price))
          |> normalize_percentage(collection, presets_count, index)

        {Map.merge(schedules, %{
           "#{index}" => %{schedule | "percentage" => updated_percentage, "price" => nil}
         }), collection + updated_percentage}
      end
    end)
  end

  defp normalize_price(price, collection, presets_count, index, total_price) do
    if index + 1 == presets_count do
      (total_price.amount - collection) |> Kernel.trunc()
    else
      price
    end
  end

  defp normalize_percentage(percentage, collection, presets_count, index) do
    if index + 1 == presets_count do
      100 - collection
    else
      percentage
    end
  end

  defp percentage_to_price(_, nil), do: nil

  defp percentage_to_price(total_price, value) do
    ((total_price.amount / 10_000 * value) |> Kernel.trunc()) * 100
  end

  defp price_to_percentage(_, nil), do: nil

  defp price_to_percentage(total_price, value) do
    if Money.zero?(value),
      do: 0,
      else: (value.amount / total_price.amount * 100) |> Kernel.trunc()
  end

  defp get_default_price(schedule, x_schedule, price, params, index) do
    if params.fixed do
      x_price =
        params.package_payment_schedules |> Enum.reduce(Money.new(0), &Money.add(&2, &1.price))

      extra_price = Money.subtract(price, x_price)

      updated_price =
        Money.add(
          Map.get(x_schedule, "price"),
          get_price(extra_price, length(params.package_payment_schedules), index)
        )

      Map.merge(schedule, %{"price" => updated_price})
    else
      schedule
    end
  end

  defp assign_payment_defaults(
         %{assigns: %{job: job, changeset: changeset}} = socket,
         job_type,
         params
       ) do
    price = remaining_price(changeset)

    params =
      if params && params.package_payment_schedules != [] do
        presets =
          map_keys(params.package_payment_schedules)
          |> Enum.with_index(
            &Map.merge(
              &1,
              %{
                "shoot_date" => get_first_shoot(job),
                "last_shoot_date" => get_last_shoot(job)
              }
              |> get_default_price(&1, price, params, &2)
            )
          )

        %{
          "total_price" => price,
          "remaining_price" => price,
          "payment_schedules" => presets,
          "fixed" => params.fixed,
          "schedule_type" => params.schedule_type
        }
      else
        default_presets = get_payment_defaults(job_type, true)

        presets =
          default_presets
          |> Enum.with_index(
            &%{
              "interval" => true,
              "shoot_date" => get_first_shoot(job),
              "last_shoot_date" => get_last_shoot(job),
              "due_interval" => &1,
              "price" => get_price(price, length(default_presets), &2)
            }
          )

        %{
          "total_price" => price,
          "remaining_price" => price,
          "payment_schedules" => presets,
          "fixed" => true,
          "schedule_type" => job_type
        }
      end

    socket
    |> assign_payments_changeset(params, :insert)
    |> assign(step: :payment)
  end

  defp save_payment(socket, %{"custom_payments" => payment_params} = params, job_id \\ nil) do
    socket
    |> maybe_assign_custom(payment_params)
    |> then(fn %{assigns: %{changeset: changeset, payments_changeset: payments_changeset}} =
                 socket ->
      payment_schedules =
        payments_changeset
        |> current()
        |> Map.from_struct()
        |> Map.get(:payment_schedules, [])
        |> Enum.map(&Map.from_struct(&1))

      total_price = Changeset.get_field(payments_changeset, :total_price)
      changeset = update_package_changeset(changeset, payments_changeset)

      opts = %{
        job_id: job_id,
        total_price: total_price,
        payment_schedules: payment_schedules,
        action: :update
      }

      case Packages.insert_or_update_package(changeset, Map.get(params, "contract"), opts) do
        {:ok, package} ->
          successfull_save(
            socket,
            package |> Repo.preload(:package_payment_schedules, force: true)
          )

        _ ->
          socket |> noreply()
      end
    end)
  end

  defp get_preset_options(payments_changeset, payment_preset) do
    payment_schedules =
      payments_changeset
      |> current()
      |> Map.from_struct()
      |> Map.get(:payment_schedules, [])
      |> Enum.map(&Map.from_struct(&1))

    if payment_preset do
      %{
        action: :update_preset,
        payment_preset: payment_preset |> Map.drop([:package_payment_schedules])
      }
    else
      %{action: :insert_preset}
    end
    |> Map.merge(%{payment_schedules: payment_schedules})
  end

  defp template_selected?(form),
    do: form |> current() |> Map.get(:package_template_id) != nil

  # takes the current changeset off the socket and returns a new changeset with the same data but new_opts
  # this is for special cases like "back." mostly we want to use params when we create a changset, not
  # the socket data.
  defp update_changeset(%{assigns: %{changeset: changeset} = assigns}, new_opts) do
    opts = assigns |> Map.take([:is_template, :step]) |> Map.to_list() |> Keyword.merge(new_opts)

    changeset
    |> current()
    |> Package.changeset(%{}, opts)
  end

  defp find_template(socket, "" <> template_id),
    do: find_template(socket, String.to_integer(template_id))

  defp find_template(%{assigns: %{templates: templates}}, template_id),
    do: Enum.find(templates, &(&1.id == template_id))

  defp changeset_from_template(socket, template_id) do
    socket
    |> find_template(template_id)
    |> changeset_from_template()
  end

  defp changeset_from_template(template), do: Packages.changeset_from_template(template)

  defp successfull_save(socket, package) do
    send(self(), {:update, %{package: package}})
    close_modal(socket)

    socket |> noreply()
  end

  defp insert_package_and_update_job(socket, changeset, job, opts) do
    case Packages.insert_package_and_update_job(changeset, job, opts) |> Repo.transaction() do
      {:ok, %{package_update: package}} ->
        successfull_save(socket, package)

      {:ok, %{package: package}} ->
        successfull_save(socket, package)

      {:error, :package, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Oops! Something went wrong. Please try again.")
        |> noreply()
    end
  end

  defp build_changeset(socket, params),
    do: Packages.build_package_changeset(socket.assigns, params)

  defp assign_changeset(socket, params, action \\ nil) do
    package_pricing_changeset =
      socket.assigns.package_pricing
      |> PackagePricing.changeset(
        Map.get(params, "package_pricing", package_pricing_params(socket.assigns.package))
      )

    multiplier_changeset =
      socket.assigns.package.base_multiplier
      |> Multiplier.from_decimal()
      |> Multiplier.changeset(Map.get(params, "multiplier", %{}))

    download_changeset =
      socket.assigns.package
      |> Download.from_package()
      |> Download.changeset(Map.get(params, "download", %{}))
      |> Map.put(:action, action)

    download = current(download_changeset)

    package_params =
      params
      |> Map.get("package", %{})
      |> PackagePricing.handle_package_params(params)
      |> Map.merge(%{
        "base_multiplier" => multiplier_changeset |> current() |> Multiplier.to_decimal(),
        "download_count" => Download.count(download),
        "download_each_price" => Download.each_price(download),
        "buy_all" => Download.buy_all(download)
      })

    changeset = build_changeset(socket, package_params) |> Map.put(:action, action)

    assign(socket,
      changeset: changeset,
      multiplier: multiplier_changeset,
      package_pricing: package_pricing_changeset,
      download: download_changeset
    )
  end

  defp base_adjustment(package_form) do
    adjustment = package_form |> current() |> Package.base_adjustment()

    sign = if Money.negative?(adjustment), do: "-", else: "+"

    Enum.join([sign, Money.abs(adjustment)])
  end

  defp total_price(form), do: form |> current() |> Package.price()

  defp next_step(%{step: step, steps: steps}) do
    Enum.at(steps, Enum.find_index(steps, &(&1 == step)) + 1)
  end

  defp package_pricing_params(nil), do: %{}

  defp package_pricing_params(package) do
    case package |> Map.get(:print_credits) do
      nil -> %{is_enabled: false}
      %Money{} = value -> %{is_enabled: Money.positive?(value)}
      _ -> %{}
    end
  end

  defp assign_contract_changeset(%{assigns: %{step: :documents}} = socket, params) do
    contract_params = Map.get(params, "contract", %{})

    contract_changeset =
      socket.assigns.changeset
      |> current()
      |> package_contract()
      |> Contract.changeset(contract_params,
        skip_package_id: true,
        validate_unique_name_on_organization:
          if(Map.get(contract_params, "edited"), do: socket.assigns.current_user.organization_id)
      )
      |> Map.put(:action, :validate)

    socket |> assign(contract_changeset: contract_changeset)
  end

  defp assign_contract_changeset(socket, _params), do: socket

  defp assign_contract_options(%{assigns: %{step: :documents}} = socket) do
    options =
      [
        {"New Contract", ""}
      ]
      |> Enum.concat(
        socket.assigns.changeset
        |> current()
        |> Contracts.for_package()
        |> Enum.map(&{&1.name, &1.id})
      )

    socket |> assign(contract_options: options)
  end

  defp assign_contract_options(socket), do: socket

  defp assign_questionnaires(
         %{
           assigns: %{
             package: %{job_type: nil},
             job: %{type: job_type}
           }
         } = socket,
         %{"package" => _package}
       ) do
    assign_questionnaires(socket, job_type)
  end

  defp assign_questionnaires(
         socket,
         %{"package" => %{"job_type" => job_type}}
       ) do
    assign_questionnaires(socket, job_type)
  end

  defp assign_questionnaires(
         %{
           assigns: %{
             current_user: %{organization_id: organization_id}
           }
         } = socket,
         job_type
       ),
       do:
         socket
         |> assign(
           :questionnaires,
           Questionnaire.for_organization_by_job_type(
             organization_id,
             job_type
           )
         )

  defp assign_questionnaires(
         %{
           assigns: %{
             package: %{job_type: job_type}
           }
         } = socket
       ) do
    assign_questionnaires(socket, job_type)
  end

  defp package_contract(package) do
    if package.contract do
      package.contract
    else
      default_contract = Contracts.default_contract(package)

      %Contract{
        content: Contracts.contract_content(default_contract, package, PicselloWeb.Helpers),
        contract_template_id: default_contract.id
      }
    end
  end

  defp interval_dropdown_options(field, index) do
    ["To Book", "6 Months Before", "Week Before", "Day Before Shoot"]
    |> Enum.map(&[key: &1, value: &1, disabled: index == 0 && field != &1])
  end

  defp payment_dropdown_options(job_type, schedule_type) do
    options = %{
      "Picsello #{job_type} default" => job_type,
      "Payment due to book" => "payment_due_book",
      "2 split payments" => "splits_2",
      "3 split payments" => "splits_3"
    }

    cond do
      schedule_type == "custom_#{job_type}" -> %{"Custom for #{job_type}" => "custom_#{job_type}"}
      schedule_type == "custom" -> %{"Custom" => "custom"}
      true -> %{}
    end
    |> Map.merge(options)
  end

  def get_payment_defaults(schedule_type, _) do
    Map.get(@payment_defaults_fixed, schedule_type, ["To Book", "6 Months Before", "Week Before"])
  end

  defp hide_add_button(form), do: input_value(form, :payment_schedules) |> length() == 3

  defp get_tags(form), do: make_tags(form) |> Enum.join(", ")

  defp make_tags(form) do
    fixed = input_value(form, :fixed)
    {_, tags} = inputs_for(form, :payment_schedules, &get_tag(&1, fixed))

    tags |> List.flatten()
  end

  defp get_tag(payment_schedule, fixed) do
    if input_value(payment_schedule, :interval) do
      if fixed,
        do: make_due_inteval_tag(payment_schedule, :price),
        else: make_due_inteval_tag(payment_schedule, :percentage)
    else
      shoot_date = input_value(payment_schedule, :shoot_date) |> is_value_set()

      if shoot_date && !input_value(payment_schedule, :count_interval) do
        make_date_tag(payment_schedule, :due_at)
      else
        make_shoot_interval(payment_schedule)
      end
    end
  end

  defp make_shoot_interval(form) do
    value = get_price_value(form)

    if value do
      time = input_value(form, :time_interval)
      count = input_value(form, :count_interval) |> String.to_integer()
      count_interval = if count == 1, do: "1 #{time}", else: "#{count} #{time}s"
      "#{value} #{count_interval} #{input_value(form, :shoot_interval)}"
    else
      ""
    end
  end

  defp make_due_inteval_tag(form, :price = field) do
    value = input_value(form, field) |> is_value_set()
    if value && value != "$", do: "#{value} to #{input_value(form, :due_interval)}", else: ""
  end

  defp make_due_inteval_tag(form, field) do
    value = input_value(form, field) |> is_value_set()
    if value && value != "%", do: "#{value}% #{input_value(form, :due_interval)}", else: ""
  end

  defp make_date_tag(form, field) do
    date = input_value(form, field) |> is_value_set()
    value = get_price_value(form)
    if date && value, do: "#{value} at #{date |> Calendar.strftime("%m-%d-%Y")}", else: ""
  end

  defp get_price_value(form) do
    price = input_value(form, :price) |> is_value_set()
    percentage = input_value(form, :percentage) |> is_value_set()

    cond do
      price && price != "$" -> price
      percentage -> "#{percentage}%"
      true -> nil
    end
  end

  defp is_value_set("" <> value), do: if(String.length(value) > 0, do: value, else: false)
  defp is_value_set(value), do: value

  defp get_remaining_price(fixed, value, total) do
    cond do
      fixed == true ->
        value

      Money.zero?(value) ->
        "#{value} (#{0.0}%)"

      true ->
        percentage = value.amount / div(total.amount, 100)
        "#{value} (#{percentage}%)"
    end
  end

  defp map_keys(payments) when is_list(payments) do
    payments
    |> Enum.map(fn payment ->
      payment
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
    end)
  end

  defp map_keys(payment) do
    payment
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end

  defp get_custom_payment_defaults(
         %{
           assigns: %{
             custom: custom,
             job_type: job_type,
             custom_schedule_type: custom_schedule_type
           }
         },
         schedule_type,
         fixed
       ) do
    if custom && schedule_type in ["custom_#{job_type}", "custom"] do
      get_payment_defaults(custom_schedule_type, fixed)
    else
      get_payment_defaults(schedule_type, fixed)
    end
  end

  defp maybe_assign_custom(%{assigns: %{is_template: false, job: _}} = socket, params),
    do: socket |> assign_payments_changeset(params, :validate)

  defp maybe_assign_custom(%{assigns: %{job_type: job_type, default: default}} = socket, params) do
    schedule_type = Map.get(params, "schedule_type")
    custom = default != map_default(params)

    if custom && schedule_type not in ["custom_#{job_type}", "custom"] do
      custom_schedule_type = schedule_type
      schedule_type = if(schedule_type == job_type, do: "custom_#{job_type}", else: "custom")

      socket
      |> assign(custom_schedule_type: custom_schedule_type)
      |> assign_payments_changeset(Map.put(params, "schedule_type", schedule_type), :validate)
    else
      socket
      |> assign_payments_changeset(params, :validate)
    end
    |> assign(custom: custom)
  end

  defp map_default(params) do
    changeset = params |> CustomPayments.changeset()

    %{
      fixed: Changeset.get_field(changeset, :fixed),
      payment_schedules:
        Enum.map(
          Changeset.get_field(changeset, :payment_schedules),
          &Map.take(&1, [:interval, :due_interval])
        )
    }
  end

  defp get_last_shoot(%{id: nil}), do: nil

  defp get_last_shoot(job) do
    shoot = if job, do: get_shoots(job.id) |> List.last(), else: nil
    if shoot, do: shoot.starts_at, else: nil
  end

  defp get_first_shoot(%{id: nil}), do: nil

  defp get_first_shoot(job) do
    shoot = if job, do: get_shoots(job.id) |> List.first(), else: nil
    if shoot, do: shoot.starts_at, else: nil
  end

  defp get_shoots(job_id), do: Shoot.for_job(job_id) |> Repo.all()
end
