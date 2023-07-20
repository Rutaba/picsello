defmodule PicselloWeb.Live.Contracts.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Contract, Contracts, Utils}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Contracts")
    |> assign(:contract_status, "current")
    |> assign(:job_type, "all")
    |> assign_contracts()
    |> ok()
  end

  @impl true
  def handle_event(
        "apply-filter-status",
        %{"option" => status},
        socket
      ) do
    socket
    |> assign(:contract_status, status)
    |> assign_contracts()
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-type",
        %{"option" => type},
        socket
      ) do
    socket
    |> assign(:job_type, type)
    |> assign_contracts()
    |> noreply()
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

      content =
        Contracts.default_contract_content(default_contract, current_user, PicselloWeb.Helpers)

      %Contract{
        content: content,
        contract_template_id: default_contract.id,
        organization_id: current_user.organization_id
      }
    end)
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{
        state: :create
      })
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
        %{
          assigns:
            %{current_user: %{organization: %{id: organization_id}} = current_user} = assigns
        } = socket
      ) do
    id = String.to_integer(contract_id)
    contract = get_contract(id)

    contract_clean =
      if is_nil(contract.organization_id) do
        content = Contracts.default_contract_content(contract, current_user, PicselloWeb.Helpers)

        %Picsello.Contract{
          organization_id: organization_id,
          content: content,
          package_id: nil,
          name: contract.name,
          job_type: contract.job_type
        }
      else
        Contracts.clean_contract_for_changeset(
          contract,
          organization_id
        )
      end
      |> Map.put(:name, nil)

    assigns = Map.merge(assigns, %{contract: contract_clean})

    socket
    |> PicselloWeb.ContractTemplateComponent.open(
      Map.merge(Map.take(assigns, [:contract, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "enable-contract",
        %{"contract-id" => contract_id},
        socket
      ) do
    id = String.to_integer(contract_id)

    case Contracts.update_contract_status(id, :active) do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Contract enabled")

      _ ->
        socket
        |> put_flash(:error, "An error occurred")
    end
    |> assign_contracts()
    |> noreply()
  end

  @impl true
  def handle_event("confirm-archive-contract", %{"contract-id" => contract_id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure you want to archive this contract?",
      confirm_event: "archive-contract_" <> contract_id,
      confirm_label: "Yes, archive the contract",
      close_label: "No! Get me out of here",
      icon: "warning-orange"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "view-contract",
        %{"contract-id" => contract_id},
        %{assigns: %{current_user: current_user} = assigns} = socket
      ) do
    id = String.to_integer(contract_id)
    contract = get_contract(id)
    content = Contracts.default_contract_content(contract, current_user, PicselloWeb.Helpers)
    contract = Map.put(contract, :content, content)
    assigns = Map.merge(assigns, %{contract: contract})

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

  @impl true
  def handle_info({:confirm_event, "archive-contract_" <> id}, socket) do
    id = String.to_integer(id)

    case Contracts.update_contract_status(id, :archive) do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Contract archived")

      _ ->
        socket
        |> put_flash(:error, "An error occurred")
    end
    |> assign_contracts()
    |> close_modal()
    |> noreply()
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

        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
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
              <button title="Trash" type="button" phx-click="confirm-archive-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
                Archive
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
            <button title="Plus" type="button" phx-click="enable-contract" phx-value-contract-id={@contract.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Unarchive
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp select_dropdown(assigns) do
    assigns =
      assigns
      |> Enum.into(%{class: ""})

    ~H"""
      <div class="flex flex-col w-full lg:w-auto mr-2 mb-3 lg:mb-0">
        <h1 class="font-extrabold text-sm flex flex-col whitespace-nowrap"><%= @title %></h1>
        <div class="flex">
          <div id={@id} class={classes("relative rounded-lg w-full lg:w-48 border-grey border p-2 cursor-pointer", %{"lg:w-64" => @id == "status"})} data-offset-y="5" phx-hook="Select">
            <div {testid("dropdown_#{@id}")} class="flex flex-row items-center border-gray-700">
                <%= Utils.capitalize_all_words(String.replace(@selected_option, "_", " ")) %>
                <.icon name="down" class="w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
                <.icon name="up" class="hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
            </div>
            <ul class={"absolute z-30 hidden mt-2 bg-white toggle rounded-md popover-content border border-base-200 #{@class}"}>
              <%= for option <- @options_list do %>
                <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
                class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">

                  <button id={"btn-#{option.id}"} class={classes("album-select", %{"w-64" => @id == "status", "w-40" => @id != "status"})} phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
                  <%= if option.id == @selected_option do %>
                    <.icon name="tick" class="w-6 h-5 ml-auto mr-1 toggle-it text-green" />
                  <% end %>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
    """
  end

  defp job_type_options do
    types =
      Picsello.JobType.all()
      |> Enum.map(fn type -> %{title: String.capitalize(type), id: type} end)

    [%{title: "All", id: "all"} | types]
  end

  defp contract_status_options do
    [
      %{title: "All", id: "all"},
      %{title: "Current", id: "current"},
      %{title: "Archived", id: "archived"}
    ]
  end

  defp assign_contracts(%{assigns: %{job_type: job_type, contract_status: contract_status, current_user: %{organization_id: organization_id}}} = socket) do
    socket
    |> assign(
      :contracts,
      Contracts.for_organization(organization_id, %{status: contract_status, type: job_type})
    )
  end

  def get_contract(id), do: Contracts.get_contract_by_id(id)
end
