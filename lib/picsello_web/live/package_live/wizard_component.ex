defmodule PicselloWeb.PackageLive.WizardComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Package, Repo, Job, JobType}
  import PicselloWeb.PackageLive.Shared, only: [package_card: 1]

  @all_fields Package.__schema__(:fields)

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> choose_initial_step()
    |> assign(:is_template, assigns |> Map.get(:job) |> is_nil())
    |> assign_changeset(%{})
    |> ok()
  end

  defp choose_initial_step(%{assigns: %{current_user: user, job: job, package: package}} = socket) do
    with %{type: job_type} <- job,
         %{id: nil} <- package,
         templates when templates != [] <-
           user |> Package.templates_for_user(job_type) |> Repo.all() do
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
    <div class="py-8 pb-3 sm:pb-8 max-w-screen-xl bare-modal">
      <div class="flex px-9">
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

        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="ml-auto">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2" />
        </button>
      </div>

      <.step_heading name={@step} is_edit={@package.id} />

      <%= unless @is_template do %>
        <div class="py-4 px-9 bg-blue-planning-100">
          <h2 class="text-2xl font-bold text-blue-planning-300"><%= Job.name @job %></h2>
          <%= unless @package.id do %>
            <.step_subheading name={@step} />
          <% end %>
        </div>
      <% end %>

      <.form for={@changeset} let={f} class="px-9" phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <input type="hidden" name="step" value={@step} />

        <.wizard_state form={f} />

        <.step name={@step} f={f} is_template={@is_template} templates={@templates} />

        <PicselloWeb.LiveModal.footer>
          <div class="flex flex-col gap-2 sm:flex-row-reverse">
            <.step_buttons name={@step} form={f} is_valid={@changeset.valid?} myself={@myself} />

            <button class="px-8 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          </div>
        </PicselloWeb.LiveModal.footer>
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
      <h1 class="mt-2 mb-4 text-3xl font-bold px-9">Package Templates</h1>
    """
  end

  def step_heading(assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl px-9"><strong class="font-bold"><%= heading_title(@is_edit) %>:</strong> <%= heading_subtitle(@name) %></h1>
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
    <button class="px-8 mb-2 sm:mb-0 btn-primary" title="Use template" type="submit" phx-disable-with="Use Template" disabled={!template_selected?(@form)}>
      Use template
    </button>

    <%= if template_selected?(@form) do %>
      <button class="px-10 mb-2 sm:mb-0 btn-secondary" title="Customize" type="button" phx-click="customize-template" phx-target={@myself}>
        Customize
      </button>
    <% else %>
      <button class="px-8 mb-2 sm:mb-0 btn-primary" title="New Package" type="button" phx-click="new-package" phx-target={@myself}>
        New Package
      </button>
    <% end %>
    """
  end

  def step_buttons(%{name: :details} = assigns) do
    ~H"""
    <button class="px-8 mb-2 sm:mb-0 btn-primary" title="Next" type="submit" disabled={!@is_valid} phx-disable-with="Next">
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
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-7">
        <%= labeled_input @f, :name, label: "Title", placeholder: "Wedding Deluxe, or 1 Hour Portrait Session", phx_debounce: "500", wrapper_class: "mt-4" %>
        <%= labeled_select @f, :shoot_count, Enum.to_list(1..10), label: "# of Shoots", wrapper_class: "mt-4", phx_update: "ignore" %>
      </div>

      <div class="flex flex-col mt-4">
        <.input_label form={@f} class="flex items-end justify-between mb-1 text-sm font-semibold" field={:description}>
          <span>Description <%= error_tag(@f, :description) %></span>

          <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-description" data-input-name={input_name(@f,:description)}>
            Clear
          </.icon_button>
        </.input_label>

        <%= input @f, :description, type: :textarea, placeholder: "Full wedding package ideal for multiple shoots across the entire wedding journey.", phx_debounce: "500" %>
      </div>

      <%= if @is_template do %>
        <div class="flex flex-col mt-4">
          <.input_label form={@f} class="mb-1 text-sm font-semibold" field={:job_type}>
            Type of Photography
          </.input_label>

          <div class="mt-2 grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-5">
            <%= for(job_type <- job_types()) do %>
              <.job_type_option type="radio" name={input_name(@f, :job_type)} job_type={job_type} checked={input_value(@f, :job_type) == job_type} />
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end

  def step(%{name: :pricing} = assigns) do
    ~H"""
      <div class="items-center mt-6 justify-items-end grid grid-cols-1 sm:grid-cols-[max-content,3fr,1fr] gap-6">
        <label class="font-bold justify-self-start sm:justify-self-end" for={input_id(@f, :base_price)}>Base Price</label>
        <div class="w-full sm:w-auto sm:col-span-2"><%= input @f, :base_price, placeholder: "$0.00", class: "w-full px-4 font-bold sm:w-28 sm:text-right text-center", phx_hook: "PriceMask" %></div>
        <hr class="w-full sm:col-span-3"/>

        <label for={input_id(@f, :gallery_credit)} class="font-bold justify-self-start sm:justify-self-end">Add</label>
        <div class="flex items-center justify-self-start">
          <%= input @f, :gallery_credit, class: "w-20 px-2 inline mr-6 text-center", placeholder: "$0.00", phx_hook: "PriceMask" %> optional Gallery store credit
        </div>
        <div class="pr-4">+<%= gallery_credit(@f) %></div>
        <hr class="w-full sm:hidden"/>

        <label for={input_id(@f, :download_count)} class="font-bold justify-self-start sm:justify-self-end">Download</label>
        <div class="flex items-center justify-self-start">
          <%= input @f, :download_count, type: :number_input, min: 0, placeholder: "0", class: "w-20 text-center inline mr-6" %>
          photos at
          <%= input @f, :download_each_price, class: "w-20 px-2 inline mx-6 text-center", placeholder: "$0.00", phx_hook: "PriceMask" %>
          <label for={input_id(@f, :download_each_price)}>each</label>
        </div>
        <div class="pr-4">+<%=downloads_total(@f) %></div>

        <hr class="w-full sm:col-span-3"/>
      </div>
      <dl class="flex justify-between mt-4">
        <dt class="font-bold">Total Price</dt>
        <dd class="pr-4 text-xl font-bold sm:col-span-2"><%= total_price(@f) %></dd>
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
  def handle_event("validate", %{"package" => params}, socket) do
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
    changeset = changeset_from_template(socket, String.to_integer(package_template_id))

    insert_package_and_update_job(socket, changeset, job)
  end

  @impl true
  def handle_event("submit", %{"package" => params, "step" => "details"}, socket) do
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
    case socket |> build_changeset(params) |> Repo.insert_or_update() do
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
    package = current_package(%{source: changeset})
    changeset = socket |> changeset_from_template(package.package_template_id)

    socket |> assign(step: :details, changeset: changeset) |> noreply()
  end

  defp template_selected?(form),
    do: form |> current_package() |> Map.get(:package_template_id) != nil

  # takes the current changeset off the socket and returns a new changeset with the same data but new_opts
  # this is for special cases like "back." mostly we want to use params when we create a changset, not
  # the socket data.
  defp update_changeset(%{assigns: %{changeset: changeset} = assigns}, new_opts) do
    opts = assigns |> Map.take([:is_template, :step]) |> Map.to_list() |> Keyword.merge(new_opts)

    changeset
    |> Ecto.Changeset.apply_changes()
    |> Package.changeset(%{}, opts)
  end

  defp changeset_from_template(%{assigns: %{templates: templates}}, template_id) do
    templates
    |> Enum.find(&(&1.id == template_id))
    |> Map.from_struct()
    |> Map.put(:package_template_id, template_id)
    |> Package.create_from_template_changeset()
  end

  defp successfull_save(socket, package) do
    send(self(), {:update, %{package: package}})
    close_modal(socket)

    socket |> noreply()
  end

  defp insert_package_and_update_job(socket, changeset, job) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:package, changeset)
      |> Ecto.Multi.update(:job, fn changes ->
        Job.add_package_changeset(job, %{package_id: changes.package.id})
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{package: package}} ->
        successfull_save(socket, package)

      {:error, :package, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      {:error, :job, _changeset, _} ->
        socket |> put_flash(:error, "Oops! Something went wrong. Please try again.") |> noreply()
    end
  end

  defp build_changeset(
         %{
           assigns: %{
             current_user: current_user,
             step: step,
             is_template: is_template,
             package: package,
             job: job
           }
         },
         params
       ) do
    params = Map.put(params, "organization_id", current_user.organization_id)

    Package.changeset(package, params,
      step: step,
      is_template: is_template,
      validate_shoot_count: job && package.id
    )
  end

  defp assign_changeset(socket, params, action \\ nil) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp current_package(form) do
    Ecto.Changeset.apply_changes(form.source)
  end

  defp gallery_credit(form),
    do: form |> current_package() |> Package.gallery_credit()

  defp downloads_total(form), do: form |> current_package() |> Package.downloads_price()

  defp total_price(form), do: form |> current_package() |> Package.price()

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defdelegate job_types(), to: JobType, as: :all
end