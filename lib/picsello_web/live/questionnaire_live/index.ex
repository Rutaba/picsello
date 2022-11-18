defmodule PicselloWeb.Live.Questionnaires.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Questionnaire, Repo}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_questionnaires()
    |> ok()
  end

  @impl true
  def handle_info({:update, %{questionnaire: _questionnaire}}, socket) do
    socket |> assign_questionnaires() |> put_flash(:success, "Questionnaire saved") |> noreply()
  end

  @impl true
  def handle_event("create-questionnaire", %{}, %{assigns: assigns} = socket) do
    case Questionnaire.changeset(%Questionnaire{}, get_questionnaire(socket))
         |> Repo.insert() do
      {:ok, questionnaire} ->
        assigns = Map.merge(assigns, %{questionnaire: questionnaire})

        socket
        |> put_flash(:success, "Questionnaire created")
        |> assign_questionnaires()
        |> PicselloWeb.QuestionnaireFormComponent.open(
          Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :create})
        )
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
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

    case Questionnaire.clean_questionnaire_for_changeset(
           get_questionnaire(id),
           socket.assigns.current_user
         )
         |> Map.put(:name, "Copy of " <> get_questionnaire(id).name)
         |> Questionnaire.changeset()
         |> Repo.insert() do
      {:ok, questionnaire} ->
        assigns = Map.merge(assigns, %{questionnaire: questionnaire})

        socket
        |> put_flash(:success, "Questionnaire duplicated")
        |> assign_questionnaires()
        |> PicselloWeb.QuestionnaireFormComponent.open(
          Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :edit})
        )
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event("delete-questionnaire", %{"questionnaire-id" => questionnaire_id}, socket) do
    id = String.to_integer(questionnaire_id)

    case Questionnaire.delete_questionnaire_by_id(id) do
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
      <div data-offset="0" phx-hook="Select" id={"manage-questionnaire-#{@questionnaire.id}"}>
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

  defp get_questionnaire(%{assigns: %{current_user: current_user}} = _socket) do
    %{
      job_type: "other",
      name: "New Questionnaire",
      questions: [
        %{
          prompt: "New question",
          type: :text
        }
      ],
      organization_id: current_user.organization_id
    }
  end

  defp get_questionnaire(id) do
    Questionnaire.get_questionnaire_by_id(id)
  end

  defp assign_questionnaires(socket) do
    socket
    |> assign(
      :questionnaires,
      Questionnaire.for_organization(socket.assigns.current_user.organization_id)
    )
  end
end
