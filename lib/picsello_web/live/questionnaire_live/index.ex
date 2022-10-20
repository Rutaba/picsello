defmodule PicselloWeb.Live.Questionnaires.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Questionnaire}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_questionnaires()
    |> ok()
  end

  @impl true
  def handle_info({:update, _questionnaire}, socket) do
    socket |> assign_questionnaires() |> put_flash(:success, "Questionnaire saved") |> noreply()
  end

  @impl true
  def handle_event("create-questionnaire", %{}, %{assigns: assigns} = socket) do
    assigns = Map.merge(assigns, %{questionnaire: get_questionnaire(socket)})

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
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: ""})
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
        %{assigns: assigns} = socket
      ) do
    id = String.to_integer(questionnaire_id)

    assigns =
      Map.merge(assigns, %{
        questionnaire:
          get_questionnaire(id)
          |> Map.put(:id, nil)
          |> Map.put(:name, "Copy of " <> get_questionnaire(id).name)
          |> Map.put(:organization_id, socket.assigns.current_user.organization_id)
          |> Map.put(:is_picsello_default, false)
          |> Map.put(:is_organization_default, false)
          |> Map.put(:inserted_at, nil)
          |> Map.put(:updated_at, nil)
          |> Map.put(:__meta__, %Picsello.Questionnaire{} |> Map.get(:__meta__))
      })

    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :edit})
    )
    |> noreply()
  end

  @impl true
  def handle_event("delete-questionnaire", %{"questionnaire-id" => questionnaire_id}, socket) do
    id = String.to_integer(questionnaire_id)

    case Questionnaire.delete_one(id) do
      {1, nil} ->
        socket
        |> put_flash(:success, "Questionnaire deleted")
        |> assign_questionnaires()
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "An error occurred")
        |> assign_questionnaires()
        |> noreply()
    end
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex items-center justify-start">
      <div phx-update="ignore" data-offset="0" phx-hook="Select">
        <button title="Manage" type="button" class="flex flex-shrink-0 ml-2 p-2.5 bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
          <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />
          <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
        </button>

        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content">
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
          <button title="Trash" type="button" phx-click="delete-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
            <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
            Delete
          </button>
          <% else %>
          <button title="Edit" type="button" phx-click="view-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold"
          >
            <.icon name="eye" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
            View
          </button>
          <button title="Edit" type="button" phx-click="duplicate-questionnaire" phx-value-questionnaire-id={@questionnaire.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold"
          >
            <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
            Duplicate
          </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_questionnaire(%{assigns: %{current_user: current_user}} = socket) do
    %Questionnaire{
      job_type: "other",
      organization_id: current_user.organization_id,
      questions: [
        %{
          prompt: "Tell me about your shoot",
          type: :text,
          placeholder: "e.g. Headshot, Birthday party"
        }
      ]
    }
  end

  defp get_questionnaire(id) do
    Questionnaire.get_one(id)
  end

  defp assign_questionnaires(socket) do
    socket
    |> assign(
      :questionnaires,
      Questionnaire.all()
    )
  end
end
