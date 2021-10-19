defmodule PicselloWeb.PackageLive.NewComponent do
  @moduledoc false

  @steps [:details, :pricing]

  use PicselloWeb, :live_component
  alias Picsello.{Package, Repo, Job}
  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(steps: @steps)
    |> assign_new(:step, fn -> :details end)
    |> assign_new(:package, fn -> %Package{} end)
    |> assign_step()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 bare-modal">
      <div class="flex px-9">
        <a {if step_number(@step) > 1, do: %{href: "#", phx_click: "back", phx_target: @myself}, else: %{}} class="flex">
          <span {testid("step-number")} class="px-2 py-0.5 mr-2 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300">
            Step <%= step_number(@step) %>
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

      <h1 class="mt-2 mb-4 text-3xl px-9"><strong class="font-bold">Add a Package:</strong> <%= @heading %></h1>

      <div class="py-4 px-9 bg-blue-planning-100">
        <h2 class="text-2xl font-bold text-blue-planning-300"><%= Job.name @job %></h2>
        <p>Create a new package</p>
      </div>

      <.form for={@changeset} let={f} class="px-9" phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <.step name={@step} f={f} />

        <PicselloWeb.LiveModal.footer>
          <div class="flex flex-col gap-2 sm:flex-row-reverse">
            <button class="px-8 mb-2 sm:mb-0 btn-primary" title={@submit_label} type="submit" disabled={!@changeset.valid?} phx-disable-with={@submit_label}>
              <%= @submit_label %>
            </button>

            <button class="px-8 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          </div>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  def step(%{name: :details} = assigns) do
    ~H"""
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-7">
        <%= labeled_input @f, :name, label: "Title", placeholder: "Super Deluxe", phx_debounce: "500", wrapper_class: "mt-4" %>
        <%= labeled_select @f, :shoot_count, Enum.to_list(1..10), label: "# of Shoots", wrapper_class: "mt-4", phx_update: "ignore" %>
      </div>

      <div class="flex flex-col mt-4">
        <.input_label form={@f} class="flex items-end justify-between mb-1 text-sm font-semibold" field={:description}>
          <span>Description <%= error_tag(@f, :description) %></span>

          <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-description" data-input-name={input_name(@f,:description)}>
            Clear
          </.icon_button>
        </.input_label>

        <%= input @f, :description, type: :textarea, placeholder: "The most deluxe of weddings", phx_debounce: "500" %>
      </div>
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

  def assign_step(%{assigns: %{step: :details}} = socket) do
    socket |> assign_changeset() |> assign(heading: "Provide Details", submit_label: "Next")
  end

  def assign_step(%{assigns: %{step: :pricing}} = socket) do
    socket |> assign_changeset() |> assign(heading: "Set Pricing", submit_label: "Save")
  end

  @impl true
  def handle_event("back", %{}, %{assigns: %{step: :pricing}} = socket) do
    socket |> assign(step: :details) |> assign_step() |> noreply()
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"package" => params}, %{assigns: %{step: :details}} = socket) do
    case socket |> assign_changeset(params, :validate) do
      %{assigns: %{changeset: %{valid?: true} = changeset}} ->
        socket
        |> assign(step: :pricing)
        |> assign_step()

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"package" => params},
        %{assigns: %{step: :pricing, job: job}} = socket
      ) do
    changeset = build_changeset(socket, params)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:package, changeset)
      |> Ecto.Multi.update(:job, fn changes ->
        Job.add_package_changeset(job, %{package_id: changes.package.id})
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{package: package}} ->
        send(self(), {:update, %{package: package}})
        close_modal(socket)

        socket |> noreply()

      {:error, :package, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      {:error, :job, _changeset, _} ->
        socket |> put_flash(:error, "Oops! Something went wrong. Please try again.") |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user, step: step, package: package}},
         params
       ) do
    params = Map.put(params, "organization_id", current_user.organization_id)

    package |> Package.create_changeset(params, step: step)
  end

  defp assign_changeset(socket, params \\ %{}, action \\ nil) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset, package: Ecto.Changeset.apply_changes(changeset))
  end

  defp current_package(form) do
    Ecto.Changeset.apply_changes(form.source)
  end

  defp gallery_credit(form),
    do: form |> current_package() |> Package.gallery_credit()

  defp downloads_total(form), do: form |> current_package() |> Package.downloads_price()

  defp total_price(form), do: form |> current_package() |> Package.price()

  defp step_number(name), do: Enum.find_index(@steps, &(&1 == name)) + 1
end
