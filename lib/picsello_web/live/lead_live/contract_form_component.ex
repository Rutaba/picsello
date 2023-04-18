defmodule PicselloWeb.ContractFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Contract, Contracts}
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.PackageLive.Shared, only: [assign_turnaround_weeks: 1]

  @impl true
  def update(%{package: package} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:content_edited, false)
    |> assign_options()
    |> assign_new(:contract, fn ->
      if package.contract do
        package_contract = assign_turnaround_weeks(package)
        struct(Contract, package_contract |> Map.take([:contract_template_id, :content]))
      else
        default_contract = Contracts.default_contract(package)

        %Contract{
          content: Contracts.contract_content(default_contract, package, PicselloWeb.Helpers),
          contract_template_id: default_contract.id
        }
      end
    end)
    |> assign_changeset(nil, %{})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 class="text-3xl font-bold mb-4">Add Custom <%= dyn_gettext @job.type %> Contract</h1>

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <div class="grid grid-flow-col auto-cols-fr gap-4 mt-4">
          <%= labeled_select f, :contract_template_id, @options, label: "Select a Contract Template" %>
          <%= labeled_input f, :name, label: "Contract Name", placeholder: "Enter new contract name", phx_debounce: "500" %>
        </div>

        <div class="flex justify-between items-end pb-2">
          <label class="block mt-4 input-label" for={input_id(f, :content)}>Contract Language</label>
          <%= cond do %>
            <% !input_value(f, :contract_template_id) -> %>
            <% @content_edited -> %>
              <.badge color={:blue}>Edited—new template will be saved</.badge>
            <% !@content_edited -> %>
              <.badge color={:gray}>No edits made</.badge>
          <% end %>
        </div>
        <.quill_input f={f} id="quill_contract_input" html_field={:content} enable_size={true} track_quill_source={true} placeholder="Paste contract text here" />
        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
          <%= if @content_edited && input_value(f, :contract_template_id) do %>
            <p class="sm:pr-4 sm:my-auto text-center text-blue-planning-300 italic text-sm">This will be saved as a new template</p>
          <% end %>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "contract" => %{"contract_template_id" => template_id},
          "_target" => ["contract", "contract_template_id"]
        },
        %{assigns: %{package: package}} = socket
      ) do
    content =
      case template_id do
        "" ->
          ""

        id ->
          package
          |> Contracts.find_by!(id)
          |> Contracts.contract_content(package, PicselloWeb.Helpers)
      end

    socket
    |> push_event("quill:update", %{"html" => content})
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"contract" => params}, socket) do
    socket
    |> assign(:content_edited, Map.get(params, "quill_source") == "user")
    |> assign_changeset(:validate, params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"contract" => params},
        %{assigns: %{package: package}} = socket
      ) do
    save_fn =
      if template_edit?(socket, params),
        do: &Contracts.save_template_and_contract/2,
        else: &Contracts.save_contract/2

    case save_fn.(package, params) do
      {:ok, contract} ->
        send(
          socket.parent_pid,
          {:contract_saved, contract}
        )

        socket |> noreply()

      {:error, changeset} ->
        socket |> assign(:changeset, changeset) |> noreply()

      _ ->
        socket |> noreply()
    end
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:job, :package]))
        }
      )

  defp assign_changeset(
         %{assigns: %{contract: contract, package: package, current_user: current_user}} = socket,
         action,
         params
       ) do
    attrs = params |> Map.put("package_id", package.id)

    changeset =
      contract
      |> Contract.changeset(attrs,
        validate_unique_name_on_organization:
          if(template_edit?(socket, params), do: current_user.organization_id)
      )
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
  end

  defp template_edit?(%{assigns: %{content_edited: content_edited}}, params) do
    content_edited || name_present?(params)
  end

  defp name_present?(params) do
    name = Map.get(params, "name") || ""
    String.trim(name) != ""
  end

  defp assign_options(%{assigns: %{package: package}} = socket) do
    options =
      [
        {"New Contract", ""}
      ]
      |> Enum.concat(package |> Contracts.for_package() |> Enum.map(&{&1.name, &1.id}))

    socket |> assign(options: options)
  end
end
