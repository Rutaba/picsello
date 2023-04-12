defmodule PicselloWeb.Live.Questionnaires.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Questionnaire}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Questionnaires")
    |> assign_questionnaires()
    |> ok()
  end

  @impl true
  def handle_event(
        "create-questionnaire",
        %{},
        %{assigns: %{current_user: %{organization_id: organization_id}} = assigns} = socket
      ) do
    assigns =
      Map.merge(assigns, %{
        questionnaire: %Picsello.Questionnaire{organization_id: organization_id}
      })

    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :create})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "view-questionnaire",
        %{"questionnaire-id" => questionnaire_id},
        %{assigns: assigns} = socket
      ) do
    id = String.to_integer(questionnaire_id)
    assigns = Map.merge(assigns, %{questionnaire: get_questionnaire(id)})

    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: nil})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-questionnaire",
        %{"questionnaire-id" => questionnaire_id},
        %{assigns: assigns} = socket
      ) do
    id = String.to_integer(questionnaire_id)
    assigns = Map.merge(assigns, %{questionnaire: get_questionnaire(id)})

    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "duplicate-questionnaire",
        %{"questionnaire-id" => questionnaire_id},
        %{assigns: %{current_user: %{organization: %{id: organization_id}}} = assigns} = socket
      ) do
    id = String.to_integer(questionnaire_id)

    questionnaire =
      Questionnaire.clean_questionnaire_for_changeset(
        get_questionnaire(id),
        organization_id
      )
      |> Map.put(:name, nil)

    assigns = Map.merge(assigns, %{questionnaire: questionnaire})

    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "update-questionnaire-status",
        %{"questionnaire-id" => questionnaire_id, "status" => status},
        socket
      ) do
    id = String.to_integer(questionnaire_id)
    status = String.to_atom(status)

    message =
      case status do
        :archive -> "Questionnaire archived"
        _ -> "Questionnaire enabled"
      end

    case Questionnaire.update_questionnaire_status(id, status) do
      {:ok, _questionnaire} ->
        socket
        |> put_flash(:success, message)

      {:error, _} ->
        socket
        |> put_flash(:error, "An error occurred")
    end
    |> assign_questionnaires()
    |> noreply()
  end

  @impl true
  def handle_event(
        "intro-close-questionnaires",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: save_intro_state(current_user, "intro_questionnaires", :dismissed))
    |> noreply()
  end

  @impl true
  def handle_info({:update, %{questionnaire: _questionnaire}}, socket) do
    socket |> assign_questionnaires() |> put_flash(:success, "Questionnaire saved") |> noreply()
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex items-center justify-end gap-3">
      <%= if @questionnaire.status == :active do %>
        <%= if @questionnaire.organization_id do %>
          <button title="Edit" type="button" phx-click="edit-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75"
              >
            <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
            Edit
          </button>
          <% else %>
          <button title="Duplicate Table" type="button" phx-click="duplicate-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75"
              >
            <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300 text-white" />
            Duplicate
          </button>
          <% end %>
      <% end %>
      <div data-offset="0" phx-hook="Select" id={"manage-questionnaire-#{@questionnaire.id}"}>
        <button title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 xl:w-auto w-full" id="Manage">
          Actions
          <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
          <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
        </button>

        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content z-20">
        <%= if @questionnaire.status == :active do %>
          <%= if @questionnaire.organization_id do %>
            <button title="Edit" type="button" phx-click="edit-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold"
            >
              <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              Edit
            </button>
            <button title="Edit" type="button" phx-click="duplicate-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold"
            >
              <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              Duplicate
            </button>
            <button title="Trash" type="button" phx-click="update-questionnaire-status" phx-value-questionnaire-id={@questionnaire.id} phx-value-status="archive" class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
              Archive
            </button>
            <% else %>
            <button title="View" type="button" phx-click="view-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold"
            >
              <.icon name="eye" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              View
            </button>
            <button title="Duplicate" type="button" phx-click="duplicate-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold" {testid("duplicate")}
            >
              <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              Duplicate
            </button>
            <% end %>
          <% else %>
            <button title="Plus" type="button" phx-click="update-questionnaire-status" phx-value-questionnaire-id={@questionnaire.id} phx-value-status="active" class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Unarchive
            </button>

          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_questionnaire(id), do: Questionnaire.get_questionnaire_by_id(id)

  defp assign_questionnaires(
         %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
       ) do
    socket
    |> assign(
      :questionnaires,
      Questionnaire.for_organization(organization_id)
    )
  end
end
