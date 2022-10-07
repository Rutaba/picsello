defmodule PicselloWeb.QuestionnaireFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Questionnaire, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset(%{}, %{})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 class="text-3xl font-bold mb-4">Add Custom Questionnaire Template</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <%= labeled_input f, :name, label: "Name", phx_debounce: "500" %>

        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:questionnaire]))
        }
      )

  @impl true
  def handle_event("validate", %{"questionnaire" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"questionnaire" => params},
        socket
      ) do
    case save_questionnaire(params, socket) do
      {:ok, questionnaire} ->
        send(socket.parent_pid, {:update, questionnaire})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp save_questionnaire(params, %{
         assigns: %{questionnaire: questionnaire}
       }) do
    questionnaire
    |> Questionnaire.changeset(params)
    |> Repo.insert()
  end

  defp assign_changeset(
         %{assigns: %{questionnaire: questionnaire}} = socket,
         params,
         action
       ) do
    attrs = params

    changeset =
      questionnaire
      |> Questionnaire.changeset(attrs)
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
  end
end
