defmodule PicselloWeb.Live.Admin.PricingCalculator do
  @moduledoc "update tax, business costs and cost categories"
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Repo, PricingCalculatorTaxSchedules}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_tax_schedules()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage the Pricing Calculator</h1>
    </header>
    <div class="p-8">
      <div class="flex items-center justify-between mb-8">
        <div>
          <h3 class="text-2xl font-bold">Tax Schedules</h3>
          <p class="text-md">Insert a tax schedule for the year and select the current year</p>
        </div>
        <button class="mb-4 btn-secondary" phx-click="add-schedule">Add tax schedule</button>
      </div>
      <%= for(%{tax_schedule: %{id: id}, changeset: changeset} <- @tax_schedules) do %>
        <div class="mb-8 border p-6 rounded-lg">
          <.form let={f} for={changeset} class="contents" phx-change="save-taxes" id={"form-#{id}"}>
            <div class="flex items-center justify-between mb-8">
              <div class="grid grid-cols-2 gap-2 items-center w-3/4">
                <div class="col-start-1 font-bold">Tax Schedule Year</div>
                <div class="col-start-2 font-bold">Tax Schedule Active</div>
                <%= hidden_input f, :id %>
                <%= select f, :year, [2022,2023,2024], class: "select py-3", phx_debounce: 200 %>
                <%= select f, :active, [true, false], class: "select py-3", phx_debounce: 200 %>
              </div>
              <button class="btn-primary" type="button" phx-click="add-income-bracket" phx-value-id={id}>Add income bracket</button>
            </div>
            <div class="grid grid-cols-4 gap-2 items-center">
              <div class="col-start-1 font-bold">Bracket Min</div>
              <div class="col-start-2 font-bold">Bracket Max</div>
              <div class="col-start-3 font-bold">Bracket Percentage</div>
              <div class="col-start-4 font-bold">Bracket Fixed Cost</div>
              <%= inputs_for f, :income_brackets, [], fn fp -> %>
                <%= input fp, :income_min, phx_debounce: 200 %>
                <%= input fp, :income_max, phx_debounce: 200 %>
                <%= input fp, :percentage, type: :number_input, phx_debounce: 200, step: 0.1, min: 1.0 %>
                <%= input fp, :fixed_cost, phx_debounce: 200 %>
              <% end %>
            </div>
          </.form>
        </div>
      <% end %>
      <div class="mt-4">
        <h3 class="text-2xl font-bold">Business Cost Categories & Line Items</h3>
        <p class="text-md">Add or modify the cost categories and the subsequent line items</p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "add-schedule",
        _,
        socket
      ) do
    socket |> add_tax_schedule() |> noreply()
  end

  @impl true
  def handle_event(
        "add-income-bracket",
        params,
        socket
      ) do
    socket
    |> add_income_bracket(params)
    |> noreply()
  end

  @impl true
  def handle_event("save-taxes", params, socket) do
    socket
    |> update_tax_schedules(params, fn tax_schedule, params ->
      case tax_schedule |> PricingCalculatorTaxSchedules.changeset(params) |> Repo.update() do
        {:ok, tax_schedule} ->
          %{
            tax_schedule: tax_schedule,
            changeset: PricingCalculatorTaxSchedules.changeset(tax_schedule)
          }

        {:error, changeset} ->
          %{tax_schedule: tax_schedule, changeset: changeset}
      end
    end)
    |> assign_tax_schedules()
    |> noreply()
  end

  defp add_income_bracket(
         %{assigns: %{tax_schedules: tax_schedules}} = socket,
         %{"id" => id}
       ) do
    id = String.to_integer(id)

    Enum.map(tax_schedules, fn
      %{tax_schedule: %{id: ^id} = tax_schedule} ->
        PricingCalculatorTaxSchedules.add_income_bracket_changeset(
          tax_schedule,
          %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
            fixed_cost: 500,
            income_max: 600,
            income_min: 100,
            percentage: 1
          }
        )
        |> Repo.update()

      tax_schedule ->
        tax_schedule
    end)

    socket
    |> assign_tax_schedules()
  end

  defp add_tax_schedule(socket) do
    PricingCalculatorTaxSchedules.changeset(%PricingCalculatorTaxSchedules{}, %{
      year: DateTime.utc_now() |> Map.fetch!(:year),
      active: false,
      income_brackets: [
        %{
          income_min: 0,
          income_max: 100,
          percentage: 1,
          fixed_cost: 500
        }
      ]
    })
    |> Repo.insert()

    socket
    |> assign_tax_schedules()
  end

  defp update_tax_schedules(
         %{assigns: %{tax_schedules: tax_schedules}} = socket,
         %{"pricing_calculator_tax_schedules" => %{"id" => id} = params},
         f
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      tax_schedules:
        Enum.map(tax_schedules, fn
          %{tax_schedule: %{id: ^id} = tax_schedule} -> f.(tax_schedule, Map.drop(params, ["id"]))
          tax_schedule -> tax_schedule
        end)
    )
  end

  defp assign_tax_schedules(socket) do
    socket
    |> assign(
      tax_schedules:
        PricingCalculatorTaxSchedules
        |> Repo.all()
        |> Enum.map(&%{tax_schedule: &1, changeset: PricingCalculatorTaxSchedules.changeset(&1)})
    )
  end
end
