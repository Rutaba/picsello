defmodule PicselloWeb.ContractTemplateComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Contract, Contracts}
  alias Picsello.{Contract, Profiles, Repo}
  import PicselloWeb.Live.Contracts.Index, only: [get_contract: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:content_edited, false)
    |> assign_job_types()
    |> assign_changeset(%{}, %{})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <div class="sm:flex items-center gap-4">
      <.step_heading state={@state} />
        <%= if is_nil(@state) do %>
          <div {testid("view-only")}><.badge color={:gray}>View Only</.badge></div>
        <% end %>
      </div>

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <h2 class="text-2xl leading-6 text-gray-900 mb-8 font-bold">Details</h2>
        <%= hidden_input f, :package_id %>

        <div class={classes(%{"grid gap-3" => @state == :edit_lead})}>
          <%= if @state == :edit_lead do %>
            <%= labeled_input f, :name, label: "Contract Name", disabled: is_nil(@state) %>
          <% else %>
            <%= labeled_input f, :name, label: "Contract Name", disabled: is_nil(@state) %>
          <% end %>
        </div>

        <div class={classes("mt-8", %{"hidden" => @state == :edit_lead})}>
          <%= label_for f, :type, label: "Type of Photography (select other to use for all types)" %>
          <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
            <%= for job_type <- @job_types do %>
              <.job_type_option type="radio" name={input_name(f, :job_type)} job_type={job_type} checked={input_value(f, :job_type) == job_type} disabled={is_nil(@state)} />
            <% end %>
          </div>
        </div>
        <hr class="my-8" />
        <div class="flex justify-between items-end pb-2">
          <label class="block mt-4 input-label" for={input_id(f, :content)}>Contract Language</label>
          <%= cond do %>
            <% @content_edited -> %>
              <.badge color={:blue}>Edited—new template will be saved</.badge>
            <% !@content_edited -> %>
              <.badge color={:gray}>No edits made</.badge>
          <% end %>
        </div>
        <.quill_input f={f} id="quill_contract_input" html_field={:content} enable_size={true} track_quill_source={true} editable= {editable(is_nil(@state))}placeholder="Paste contract text here" />

        <.footer>
          <%= if !is_nil(@state)do %>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>
          <% else %>
          <button title="Duplicate Table" type="button" phx-click="duplicate-contract" phx-value-contract-id={@contract.id} phx-target={@myself} class="btn-primary">
            Duplicate
          </button>
          <% end %>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            <%= if is_nil(@state) do %>Close<% else %>Cancel<% end %>
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  def step_heading(assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl font-bold"><%= heading_title(@state) %></h1>
    """
  end

  def heading_title(state) do
    case state do
      :edit -> "Edit Contract"
      :edit_lead -> "Edit Contract"
      :create -> "Add Contract"
      _ -> "View Contract template"
    end
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:contract]))
        }
      )

  defp assign_job_types(
         %{
           assigns: %{
             current_user: %{organization: %{organization_job_types: job_types}}
           }
         } = socket
       ) do
    socket
    |> assign_new(:job_types, fn ->
      (Profiles.enabled_job_types(job_types) ++
         [Picsello.JobType.other_type()])
      |> Enum.uniq()
    end)
  end

  defp assign_changeset(
         %{assigns: %{contract: contract}} = socket,
         action,
         params
       ) do
    attrs = Map.get(params, "contract", %{})

    changeset =
      contract
      |> Contract.template_changeset(attrs)
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
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

    assigns = Map.merge(assigns, %{contract: contract, state: :edit})
    assigns = Map.take(assigns, [:contract, :current_user, :state])

    socket
    |> assign(assigns)
    |> noreply()
  end

  @impl true
  def handle_event("validate", params, socket) do
    contract = Map.get(params, "contract", %{"quill_source" => ""})

    socket
    |> assign(:content_edited, Map.get(contract, "quill_source") == "user")
    |> assign_changeset(:validate, params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"contract" => params},
        socket
      ) do
    case save_contract(params, socket) do
      {:ok, contract} ->
        send(socket.parent_pid, {:update, %{contract: contract}})

        socket |> close_modal()

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  defp save_contract(params, %{assigns: %{contract: contract}}) do
    params =
      params
      |> Map.put("organization_id", contract.organization_id)
      |> Map.put("package_id", nil)
      |> Map.put("contract_template_id", nil)

    contract =
      contract |> Map.drop([:contract_template_id, :organization, :package, :contract_template])

    contract
    |> Contract.template_changeset(params)
    |> Repo.insert_or_update()
  end

  defp editable(false), do: "true"
  defp editable(true), do: "false"
end
