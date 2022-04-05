defmodule PicselloWeb.PackageLive.WizardComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  alias Picsello.{
    Package,
    Packages,
    Packages.Multiplier,
    Packages.Download,
    Packages.PackagePricing
  }

  import PicselloWeb.PackageLive.Shared,
    only: [
      package_card: 1,
      quill_input: 1,
      package_basic_fields: 1,
      digital_download_fields: 1,
      current: 1
    ]

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @all_fields Package.__schema__(:fields)

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> assign_new(:package_pricing, fn -> %PackagePricing{} end)
    |> choose_initial_step()
    |> assign(is_template: assigns |> Map.get(:job) |> is_nil(), job_types: Packages.job_types())
    |> assign_changeset(%{})
    |> ok()
  end

  defp choose_initial_step(%{assigns: %{current_user: user, job: job, package: package}} = socket) do
    with %{type: job_type} <- job,
         %{id: nil} <- package,
         templates when templates != [] <- Packages.templates_for_user(user, job_type) do
      socket
      |> assign(
        templates: templates,
        step: :choose_template,
        steps: [:choose_template, :details, :pricing]
      )
    else
      _ -> socket |> assign(templates: [], step: :details, steps: [:details, :pricing])
    end
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

      <.step_heading name={@step} is_edit={@package.id} />

      <%= unless @is_template do %>
        <div class="py-4 bg-gray-100 modal-banner mb-4">
          <h2 class="text-2xl font-bold"><%= Packages.job_name @job %></h2>
          <%= unless @package.id do %>
            <.step_subheading name={@step} />
          <% end %>
        </div>
      <% end %>

      <.form for={@changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <input type="hidden" name="step" value={@step} />

        <.wizard_state form={f} />

        <.step name={@step} f={f} {assigns} />

        <.footer>
          <.step_buttons name={@step} form={f} is_valid={Enum.all?([@download, @package_pricing, @multiplier, @changeset], &(&1.valid?))} myself={@myself} />

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  def wizard_state(assigns) do
    fields = @all_fields

    ~H"""
      <%= for field <- fields, input_value(@form, field) do %>
        <%= hidden_input @form, field, id: nil %>
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

  def step_buttons(%{name: :details} = assigns) do
    ~H"""
    <button class="btn-primary" title="Next" type="submit" disabled={!@is_valid} phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{name: :pricing} = assigns) do
    ~H"""
    <button class="px-8 mb-2 sm:mb-0 btn-primary" title="Save" type="submit" disabled={!@is_valid} phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{name: :choose_template} = assigns) do
    ~H"""
    <h1 class="mt-6 text-xl font-bold">Select Package <%= if template_selected?(@f), do: "(1 selected)", else: "" %></h1>
      <div class="my-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-7">
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
      <.package_basic_fields form={@f} />

      <div class="flex flex-col mt-4">

        <.input_label form={@f} class="flex items-end justify-between mb-1 text-sm font-semibold" field={:description}>
          <span>Description <%= error_tag(@f, :description) %></span>
          <.icon_button color="red-sales-300" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(@f,:description)}>
            Clear
          </.icon_button>
        </.input_label>
        <.quill_input f={@f} style={"min-height: 8rem;"} html_field={:description} placeholder={"Full wedding package ideal for multiple shoots across the entire wedding journey."} />
      </div>

      <%= if @is_template do %>
        <div class="flex flex-col mt-4">
          <.input_label form={@f} class="mb-1 text-sm font-semibold" field={:job_type}>
            Type of Photography
          </.input_label>

          <div class="mt-2 grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-5">
            <%= for job_type <- @job_types do %>
              <.job_type_option type="radio" name={input_name(@f, :job_type)} job_type={job_type} checked={input_value(@f, :job_type) == job_type} />
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end

  def step(%{name: :pricing} = assigns) do
    ~H"""
      <div class="">
          <div class="flex flex-col items-start justify-between w-full sm:items-center sm:flex-row sm:w-auto">
            <label for={input_id(@f, :base_price)}>
              <h2 class="mb-1 text-xl font-bold">Creative Session Price</h2>
              Your cost in labor, travel, etc including download and print credits
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

        <hr class="block w-full mt-6 sm:hidden"/>

        <.digital_download_fields package_form={@f} download={@download} package_pricing={@package_pricing} />

        <div class="mt-6 sm:mt-9">
          <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Print Credits</h2>
        </div>

        <div class="flex flex-col justify-between mt-6 sm:flex-row ">
          <% p = form_for(@package_pricing, "#") %>

          <div class="flex flex-row space-x-8">
            <label class="flex items-center">
              <%= checkbox(p, :is_enabled, class: "w-5 h-5 mr-2.5 checkbox") %>

              Add
            </label>

            <%= if p |> current() |> Map.get(:is_enabled) do %>
              <%= input(@f, :print_credits, placeholder: "$0.00", class: "mt-2 w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>

              <div class="flex items-center">Gallery store credit</div>
            <% end %>
          </div>
        </div>
      </div>
      <hr class="w-full mt-8"/>
      <dl class="flex justify-between mt-4">
        <dt class="font-bold">Total Price</dt>
        <dd class="text-xl font-bold"><%= total_price(@f) %></dd>
      </dl>
    """
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
    changeset = changeset_from_template(socket, package_template_id)

    insert_package_and_update_job(socket, changeset, job)
  end

  @impl true
  def handle_event("submit", %{"step" => "details"} = params, socket) do
    case socket |> assign_changeset(params, :validate) do
      %{assigns: %{changeset: %{valid?: true}}} ->
        socket |> assign(step: :pricing) |> assign_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"package" => params, "step" => "pricing"},
        %{assigns: %{is_template: false, job: job, package: %Package{id: nil}}} = socket
      ) do
    changeset = build_changeset(socket, params)
    insert_package_and_update_job(socket, changeset, job)
  end

  @impl true
  def handle_event(
        "submit",
        %{"package" => params, "step" => "pricing"},
        socket
      ) do
    case Packages.insert_or_update_package(socket.assigns, params) do
      {:ok, package} ->
        successfull_save(socket, package)

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

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

    template = find_template(socket, package.package_template_id)

    changeset = changeset_from_template(template)

    socket
    |> assign(
      step: :details,
      package:
        Map.merge(
          socket.assigns.package,
          Map.take(template, [:download_each_price, :download_count, :base_multiplier])
        ),
      changeset: changeset
    )
    |> noreply()
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

  defp changeset_from_template(%{id: template_id} = template) do
    template
    |> Map.from_struct()
    |> Map.put(:package_template_id, template_id)
    |> Package.create_from_template_changeset()
  end

  defp successfull_save(socket, package) do
    send(self(), {:update, %{package: package}})
    close_modal(socket)

    socket |> noreply()
  end

  defp insert_package_and_update_job(socket, changeset, job),
    do:
      (case(Packages.insert_package_and_update_job(changeset, job)) do
         {:ok, %{package: package}} ->
           successfull_save(socket, package)

         {:error, :package, changeset, _} ->
           socket |> assign(changeset: changeset) |> noreply()

         {:error, :job, _changeset, _} ->
           socket
           |> put_flash(:error, "Oops! Something went wrong. Please try again.")
           |> noreply()
       end)

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
        "download_each_price" => Download.each_price(download)
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

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defp package_pricing_params(package) do
    print_credits =
      case package |> Map.get(:print_credits) do
        nil -> %{is_enabled: false}
        %Money{} = value -> %{is_enabled: Money.positive?(value)}
        %{} -> %{}
      end

    case package |> Map.get(:buy_all) do
      nil -> Map.put(print_credits, :is_buy_all, false)
      %Money{} = value -> Map.put(print_credits, :is_buy_all, Money.positive?(value))
      %{} -> %{}
    end
  end
end
