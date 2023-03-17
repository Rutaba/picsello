defmodule PicselloWeb.Live.Contracts.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Contract, Contracts}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

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
  def handle_info({:update, %{contract: _contract}}, socket) do
    socket |> assign_contracts() |> put_flash(:success, "Contract saved") |> noreply()
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex items-center justify-end gap-3">
      <%= if @contract.organization_id do %>
      <button title="Edit" type="button" phx-click="edit-contract" phx-value-contract-id={@contract.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75"
          >
        <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
        Edit
      </button>
      <% end %>
    </div>
    """
  end

  defp assign_contracts(socket) do
    contracts = Contracts.for_organization(socket.assigns.current_user.organization_id)

    socket
    |> assign(
      :contracts,
      contracts
    )
  end

  defp get_contract(id), do: Contracts.get_contract_by_id(id)
end
