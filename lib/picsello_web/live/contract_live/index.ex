defmodule PicselloWeb.Live.Contracts.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Contract, Contracts}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Contracts")
    |> assign_contracts()
    |> ok()
  end

  @impl true
  def handle_event(
        "create-contract",
        %{},
        %{assigns: %{current_user: current_user} = assigns} = socket
      ) do
    socket
    |> assign_new(:contract, fn ->
      default_contract = Contracts.get_default_template()

      %Contract{
        content:
          Contracts.default_contract_content(default_contract, current_user, PicselloWeb.Helpers),
        contract_template_id: default_contract.id,
        organization_id: current_user.organization_id
      }
    end)
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{state: :create})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-contract",
        %{"contract-id" => contract_id},
        %{assigns: assigns} = socket
      ) do
    id = String.to_integer(contract_id)
    assigns = Map.merge(assigns, %{contract: get_contract(id)})

    socket
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "duplicate-contract",
        %{"contract-id" => contract_id},
        %{assigns: %{current_user: %{organization: %{id: organization_id}}} = assigns} = socket
      ) do
    id = String.to_integer(contract_id)

    contract =
      Contracts.clean_contract_for_changeset(
        get_contract(id),
        organization_id
      )
      |> Map.put(:name, nil)

    assigns = Map.merge(assigns, %{contract: contract})

    socket
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "update-contract-status",
        %{"contract-id" => contract_id, "status" => status},
        socket
      ) do
    id = String.to_integer(contract_id)
    status = String.to_atom(status)

    message =
      case status do
        :archive -> "Contract deleted"
        _ -> "Contract enabled"
      end

    case Contracts.update_contract_status(id, status) do
      {:ok, _} ->
        socket
        |> put_flash(:success, message)

      _ ->
        socket
        |> put_flash(:error, "An error occurred")
    end
    |> assign_contracts()
    |> noreply()
  end

  @impl true
  def handle_event(
        "view-contract",
        %{"contract-id" => contract_id},
        %{assigns: assigns} = socket
      ) do
    id = String.to_integer(contract_id)
    assigns = Map.merge(assigns, %{contract: get_contract(id)})

    socket
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{state: nil})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "intro-close-contract",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: save_intro_state(current_user, "intro_contract", :dismissed))
    |> noreply()
  end

  @impl true
  def handle_info({:update, %{contract: _contract}}, socket) do
    socket |> assign_contracts() |> put_flash(:success, "Contract saved") |> noreply()
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex items-center justify-end gap-3">
      <%= if @contract.status == :active do %>
        <%= if @contract.organization_id do %>
          <button title="Edit" type="button" phx-click="edit-contract" phx-value-contract-id={@contract.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75" >
            <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
            Edit
          </button>
        <% else %>
          <button title="Duplicate Table" type="button" phx-click="duplicate-contract" phx-value-contract-id={@contract.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75">
            <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300 text-white" />
            Duplicate
          </button>
        <% end %>
      <% end %>
      <div data-offset="0" phx-hook="Select" id={"manage-contract-#{@contract.id}"}>
        <button {testid("actions")} title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 xl:w-auto w-full">
          Actions
          <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
          <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
        </button>

        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content z-20">
          <%= if @contract.status == :active do %>
            <%= if @contract.organization_id do %>
              <button title="Edit" type="button" phx-click="edit-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Edit
              </button>
              <button title="Duplicate Table" type="button" phx-click="duplicate-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Duplicate
              </button>
              <button title="Trash" type="button" phx-click="update-contract-status" phx-value-contract-id={@contract.id} phx-value-status="archive" class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
                Delete
              </button>
              <% else %>
              <button title="View" type="button" phx-click="view-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="eye" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                View
              </button>
              <button title="Duplicate" type="button" phx-click="duplicate-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold" {testid("duplicate")}>
                <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Duplicate
              </button>
            <% end %>
          <% else %>
            <button title="Plus" type="button" phx-click="update-contract-status" phx-value-contract-id={@contract.id} phx-value-status="active" class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Unarchive
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp assign_contracts(%{assigns: %{current_user: %{organization_id: organization_id}}} = socket) do
    contracts = Contracts.for_organization(organization_id)

    socket
    |> assign(
      :contracts,
      contracts
    )
  end

  defp get_contract(id), do: Contracts.get_contract_by_id(id)
end
