defmodule PicselloWeb.QuestionnaireFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Questionnaire, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> assign_changeset(%{}, %{})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <div class="sm:flex items-center gap-4">
      <.step_heading state={@state} />
        <%= if @state === "" do %>
          <div><.badge color={:gray}>View Only</.badge></div>
        <% end %>
      </div>


      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <%= labeled_input f, :name, label: "Name", phx_debounce: "500", disabled: @state === "" %>

        <div class="sm:col-span-3">
        <%= label_for f, :type, label: "Type of Photography" %>
        <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
          <%= for job_type <- @job_types do %>
            <.job_type_option type="radio" name={input_name(f, :job_type)} job_type={job_type} checked={input_value(f, :job_type) == job_type} disabled={@state === ""} />
          <% end %>
        </div>
      </div>

        <PicselloWeb.LiveModal.footer>
          <%= if @state !== "" do %>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>
          <% end %>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            <%= if @state == "" do %>Close<% else %>Cancel<% end %>
          </button>
        </PicselloWeb.LiveModal.footer>
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
      :edit -> "Edit custom questionnaire"
      :create -> "Add custom questionnaire"
      _ -> "View custom questionnaire"
    end
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
    |> Map.drop([:organization])
    |> Questionnaire.changeset(params)
    |> Repo.insert_or_update()
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

  defp assign_job_types(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    socket
    |> assign_new(:job_types, fn ->
      (organization.profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq()
    end)
  end
end
