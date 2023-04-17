defmodule PicselloWeb.Live.Admin.PricingCalculator do
  @moduledoc "update tax, business costs and cost categories"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, PricingCalculatorTaxSchedules, PricingCalculatorBusinessCosts}

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_tax_schedules()
    |> assign_business_costs()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage the Smart Profit Calculator™</h1>
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
        <div class="mb-8 border rounded-lg">
          <.form :let={f} for={changeset} class="contents" phx-change="save-taxes" id={"form-taxes-#{id}"}>
            <div class="flex items-center justify-between mb-8 bg-gray-100  p-6 ">
              <div class="grid grid-cols-3 gap-2 items-center w-3/4">
                <div class="col-start-1 font-bold">Tax Schedule Year</div>
                <div class="col-start-2 font-bold">Tax Schedule Active</div>
                <div class="col-start-3 font-bold">Tax Schedule Fixed Self Employment Tax</div>
                <%= hidden_input f, :id %>
                <%= select f, :year, generate_years(), class: "select py-3", phx_debounce: 200 %>
                <%= select f, :active, [true, false], class: "select py-3", phx_debounce: 200 %>
                <%= input f, :self_employment_percentage, type: :number_input, phx_debounce: 200, step: 0.1, min: 1.0 %>
              </div>
              <button class="btn-primary" type="button" phx-click="add-income-bracket" phx-value-id={id}>Add income bracket</button>
            </div>
            <div class="grid grid-cols-5 gap-2 items-center px-6 pb-6">
              <div class="col-start-1 font-bold">Bracket Min</div>
              <div class="col-start-2 font-bold">Bracket Max</div>
              <div class="col-start-3 font-bold">Bracket % Over Fixed Cost Start</div>
              <div class="col-start-4 font-bold">Bracket Fixed Cost Start</div>
              <div class="col-start-5 font-bold">Bracket Fixed Cost</div>
              <%= inputs_for f, :income_brackets, [], fn fp -> %>
                <%= input fp, :income_min, phx_debounce: 200, phx_hook: "PriceMask" %>
                <%= input fp, :income_max, phx_debounce: 200, phx_hook: "PriceMask" %>
                <%= input fp, :percentage, type: :number_input, phx_debounce: 200, step: 0.1, min: 1.0 %>
                <%= input fp, :fixed_cost_start, phx_debounce: 200, phx_hook: "PriceMask" %>
                <%= input fp, :fixed_cost, phx_debounce: 200, phx_hook: "PriceMask" %>
              <% end %>
            </div>
          </.form>
        </div>
      <% end %>
      <div class="mt-4">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h3 class="text-2xl font-bold">Business Cost Categories & Line Items</h3>
            <p class="text-md">Add or modify the cost categories and the subsequent line items</p>
          </div>
          <button class="mb-4 btn-secondary" phx-click="add-business-cost-category">Add cost category</button>
        </div>
        <%= for(%{business_cost: %{id: id}, changeset: changeset} <- @business_costs) do %>
        <div class="mb-8 border rounded-lg">
          <.form :let={fcosts} for={changeset} class="contents" phx-change="save-line-items" id={"form-line-items-#{id}"}>
            <div class="flex items-center justify-between mb-8 bg-gray-100  p-6 ">
              <div class="grid grid-cols-3 gap-2 items-center w-3/4">
                <div class="col-start-1 font-bold">Category Title</div>
                <div class="col-start-2 font-bold">Category Description</div>
                <div class="col-start-3 font-bold">Should this cost category by a default?</div>
                <%= hidden_input fcosts, :id %>
                <%= input fcosts, :category, phx_debounce: 200 %>
                <%= input fcosts, :description, phx_debounce: 200 %>
                <%= select fcosts, :active, [true, false], class: "select py-3", phx_debounce: 200 %>
              </div>
              <button class="btn-primary" type="button" phx-click="add-line-item" phx-value-id={id}>Add line item</button>
            </div>
            <div class="grid grid-cols-3 gap-2 items-center px-6 pb-6">
              <div class="col-start-1 font-bold">Title</div>
              <div class="col-start-2 font-bold">Description</div>
              <div class="col-start-3 font-bold">Yearly cost</div>
              <%= inputs_for fcosts, :line_items, [], fn fl -> %>
                <%= input fl, :title, phx_debounce: 200 %>
                <%= input fl, :description, phx_debounce: 200 %>
                <%= input fl, :yearly_cost, phx_debounce: 200, phx_hook: "PriceMask" %>
              <% end %>
            </div>
          </.form>
        </div>
      <% end %>
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
        "add-business-cost-category",
        _,
        socket
      ) do
    socket |> add_business_cost_category() |> noreply()
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
  def handle_event(
        "add-line-item",
        params,
        socket
      ) do
    socket
    |> add_line_item(params)
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

  @impl true
  def handle_event("save-line-items", params, socket) do
    socket
    |> update_business_costs(params, fn business_cost, params ->
      case business_cost |> PricingCalculatorBusinessCosts.changeset(params) |> Repo.update() do
        {:ok, business_cost} ->
          %{
            business_cost: business_cost,
            changeset: PricingCalculatorBusinessCosts.changeset(business_cost)
          }

        {:error, changeset} ->
          %{business_cost: business_cost, changeset: changeset}
      end
    end)
    |> assign_business_costs()
    |> noreply()
  end

  defp add_income_bracket(
         %{assigns: %{tax_schedules: tax_schedules}} = socket,
         %{"id" => id}
       ) do
    id = String.to_integer(id)

    Enum.each(tax_schedules, fn
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

      _tax_schedule ->
        nil
    end)

    socket
    |> assign_tax_schedules()
  end

  defp add_line_item(
         %{assigns: %{business_costs: business_costs}} = socket,
         %{"id" => id}
       ) do
    id = String.to_integer(id)

    Enum.each(business_costs, fn
      %{business_cost: %{id: ^id} = business_cost} ->
        PricingCalculatorBusinessCosts.add_business_cost_changeset(
          business_cost,
          %Picsello.PricingCalculatorBusinessCosts.BusinessCost{}
        )
        |> Repo.update()

      _business_cost ->
        nil
    end)

    socket
    |> assign_business_costs()
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

  defp add_business_cost_category(socket) do
    PricingCalculatorBusinessCosts.changeset(%PricingCalculatorBusinessCosts{}, %{
      category: "",
      inserted_at: DateTime.utc_now(),
      active: true,
      line_items: [
        %{
          title: "",
          description: "",
          fixed_cost: 0
        }
      ]
    })
    |> Repo.insert()

    socket
    |> assign_business_costs()
  end

  defp update_tax_schedules(
         %{assigns: %{tax_schedules: tax_schedules}} = socket,
         %{"pricing_calculator_tax_schedules" => %{"id" => id} = params},
         tax_schedule_update_fn
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      tax_schedules:
        Enum.map(tax_schedules, fn
          %{tax_schedule: %{id: ^id} = tax_schedule} ->
            tax_schedule_update_fn.(tax_schedule, Map.drop(params, ["id"]))

          _tax_schedule ->
            nil
        end)
    )
  end

  defp update_business_costs(
         %{assigns: %{business_costs: business_costs}} = socket,
         %{"pricing_calculator_business_costs" => %{"id" => id} = params},
         fcosts
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      business_costs:
        Enum.map(business_costs, fn
          %{business_cost: %{id: ^id} = business_cost} ->
            fcosts.(business_cost, Map.drop(params, ["id"]))

          _business_cost ->
            nil
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

  defp assign_business_costs(socket) do
    socket
    |> assign(
      business_costs:
        PricingCalculatorBusinessCosts
        |> order_by(asc: :inserted_at)
        |> Repo.all()
        |> Enum.map(
          &%{business_cost: &1, changeset: PricingCalculatorBusinessCosts.changeset(&1)}
        )
    )
  end

  def generate_years(), do: Enum.map(0..5, &(2022 + &1))
end
