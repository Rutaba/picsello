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
        <h2 class="text-2xl leading-6 text-gray-900 mb-8 font-bold">Details</h2>

        <%= labeled_input f, :name, label: "Name", phx_debounce: "500", disabled: @state === "" %>

        <div class="mt-8">
          <%= label_for f, :type, label: "Type of Photography" %>
          <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
            <%= for job_type <- @job_types do %>
              <.job_type_option type="radio" name={input_name(f, :job_type)} job_type={job_type} checked={input_value(f, :job_type) == job_type} disabled={@state === ""} />
            <% end %>
          </div>
        </div>

        <hr class="my-8" />

        <h2 class="text-2xl leading-6 text-gray-900 mb-8 font-bold">Questions</h2>

        <fieldset>
          <%= for f_questions <- inputs_for(f, :questions) do %>
            <div class="mb-8 border rounded-lg">
              <%= hidden_inputs_for(f_questions) %>
              <%= if @state !== "" do %>
              <div class="sm:flex items-center justify-between bg-gray-100 p-4 rounded-t-lg">
                <div>
                  <h3 class="text-lg font-bold">Question <%= f_questions.index + 1 %></h3>
                </div>
                <div class="flex items-center gap-4">
                  <button class="bg-red-sales-100 border border-red-sales-300 hover:border-transparent rounded-lg flex items-center p-2" type="button" phx-click="delete-question" phx-target={@myself} phx-value-id={f_questions.index}>
                    <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
                  </button>
                  <button class="bg-white border hover:border-white rounded-lg flex items-center p-2" type="button" phx-click="reorder-question" phx-target={@myself} phx-value-direction="down">
                    <.icon name="down" class="inline-block w-4 h-4 stroke-current stroke-3 text-black" />
                  </button>
                  <button class="bg-white border hover:border-white rounded-lg flex items-center p-2" type="button" phx-click="reorder-question" phx-target={@myself} phx-value-direction="up">
                    <.icon name="up" class="inline-block w-4 h-4 stroke-current stroke-3 text-black" />
                  </button>
                </div>
              </div>
              <% end %>
              <div class="p-4">
                <div class="grid sm:grid-cols-3 gap-6">
                  <%= labeled_input f_questions, :prompt, phx_debounce: 200, label: "Question Prompt", type: :textarea, placeholder: "Enter the question you'd like to ask…", disabled: @state === "", wrapper_class: "sm:col-span-2" %>
                  <label class="flex items-center mt-6 sm:mt-8 justify-self-start sm:col-span-1 cursor-pointer">
                    <%= checkbox f_questions, :optional, class: "w-5 h-5 mr-2 checkbox", disabled: @state === "" %>
                    <strong>Optional</strong> <em>(your client can skip this question)</em>
                  </label>
                </div>
                <div class="flex flex-col mt-6">
                  <%= labeled_input f_questions, :placeholder, phx_debounce: 200, label: "Question Preview", placeholder: "Enter the preview you'd like you're client to see…", disabled: @state === "" %>
                </div>
                <div class="flex flex-col mt-6">
                  <%= label_for f_questions, :type, label: "Question Type" %>
                  <%= select f_questions, :type, field_options(), class: "select", disabled: @state === "" %>
                </div>

                <%= case input_value(f_questions, :type) do %>
                  <% :multiselect -> %>
                  <.options_editor myself={@myself} f_questions={f_questions} state={@state} />

                  <% :select -> %>
                  <.options_editor myself={@myself} f_questions={f_questions} state={@state} />

                  <% "multiselect" -> %>
                  <.options_editor myself={@myself} f_questions={f_questions} state={@state} />

                  <% "select" -> %>
                  <.options_editor myself={@myself} f_questions={f_questions} state={@state} />

                  <% _ -> %>
                <% end %>
              </div>
            </div>
          <% end %>
        </fieldset>

        <%= if @state !== "" do %>
        <div class="mt-8">
          <.icon_button {testid("add-question")} phx-click="add-question" phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add question" color="blue-planning-300" icon="plus">
            Add question
          </.icon_button>
        </div>
        <% end %>

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
  def handle_event("add-question", %{}, %{assigns: %{questionnaire: questionnaire}} = socket) do
    questions = questionnaire.questions

    questions
    |> List.insert_at(-1, %Picsello.Questionnaire.Question{
      optional: false,
      options: [],
      placeholder: "",
      prompt: "",
      type: :text
    })
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

  @impl true
  def handle_event(
        "reorder-question",
        %{"direction" => direction},
        %{assigns: %{questionnaire: %{questions: questions}}} = socket
      ) do
    questions
    |> swap(direction)
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

  @impl true
  def handle_event(
        "delete-question",
        %{"id" => id},
        %{assigns: %{questionnaire: %{questions: questions}}} = socket
      ) do
    index = String.to_integer(id)

    questions
    |> List.delete_at(index)
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

  @impl true
  def handle_event(
        "edit-option",
        %{"id" => id, "option-id" => option_id, "value" => value},
        %{assigns: %{questionnaire: %{questions: questions}}} = socket
      ) do
    index = String.to_integer(id)
    option_index = String.to_integer(option_id)

    new_option_list =
      questions
      |> Enum.fetch!(index)
      |> Map.get(:options)
      |> List.replace_at(option_index, value)

    new_question = questions |> Enum.fetch!(index) |> Map.put(:options, new_option_list)

    questions
    |> List.replace_at(index, new_question)
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

  @impl true
  def handle_event(
        "delete-option",
        %{"id" => id, "option-id" => option_id},
        %{assigns: %{questionnaire: %{questions: questions}}} = socket
      ) do
    index = String.to_integer(id)
    option_index = String.to_integer(option_id)

    new_option_list =
      questions
      |> Enum.fetch!(index)
      |> Map.get(:options)
      |> List.delete_at(option_index)

    new_question = questions |> Enum.fetch!(index) |> Map.put(:options, new_option_list)

    questions
    |> List.replace_at(index, new_question)
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

  @impl true
  def handle_event(
        "add-option",
        %{"id" => id},
        %{assigns: %{questionnaire: %{questions: questions}}} = socket
      ) do
    index = String.to_integer(id)

    new_option_list =
      questions
      |> Enum.fetch!(index)
      |> Map.get(:options)
      |> List.insert_at(-1, "")

    new_question = questions |> Enum.fetch!(index) |> Map.put(:options, new_option_list)

    questions
    |> List.replace_at(index, new_question)
    |> assign_question_changeset(socket)
    |> save_questionnaire()
  end

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

  defp options_editor(assigns) do
    ~H"""
    <div class="mt-6">
      <h4 class="font-bold mb-2">Options</h4>
      <ul class="mb-6">
        <%= for {option, index} <- input_value(@f_questions, :options) |> Enum.with_index() do %>
          <li class="mb-2 flex items-center gap-2">
            <input type="text" class="text-input" value={option} placeholder="Enter an option…" phx-blur="edit-option" phx-value-id={@f_questions.index} phx-value-option-id={index} phx-target={@myself} disabled={@state === ""} />
            <%= if @state !== "" do %>
            <button class="bg-red-sales-100 border border-red-sales-300 hover:border-transparent rounded-lg flex items-center p-2" type="button" phx-click="delete-option" phx-value-id={@f_questions.index} phx-value-option-id={index} phx-target={@myself}>
              <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
            </button>
            <% end %>
          </li>
        <% end %>
      </ul>
      <%= if @state !== "" do %>
      <.icon_button {testid("add-option")} phx-click="add-option" phx-value-id={@f_questions.index} phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add question" color="blue-planning-300" icon="plus">
        Add option
      </.icon_button>
      <%= end %>
    </div>
    """
  end

  defp assign_question_changeset(questions, socket) do
    map = questions |> Enum.map(fn question -> question |> Map.from_struct() end)

    socket |> assign_changeset(%{questions: map}, :update)
  end

  defp save_questionnaire(params, %{
         assigns: %{questionnaire: questionnaire}
       }) do
    questionnaire
    |> Map.drop([:organization])
    |> Questionnaire.changeset(params)
    |> Repo.insert_or_update()
  end

  defp save_questionnaire(
         %{
           assigns: %{changeset: changeset}
         } = socket
       ) do
    case changeset
         |> Repo.insert_or_update() do
      {:ok, questionnaire} ->
        socket |> assign(questionnaire: questionnaire) |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
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

  defp field_options do
    [
      {"Text (simple text box)", :text},
      {"Textarea (multiline text box)", :textarea},
      {"Select (dropdown of options)", :select},
      {"Date (date picker)", :date},
      {"Multiselect (checkboxes)", :multiselect},
      {"Phone", :phone},
      {"Email", :email}
    ]
  end

  defp swap(questions, direction) do
    case direction do
      "up" ->
        {el, list} = questions |> List.pop_at(0)

        list |> List.insert_at(length(list), el)

      "down" ->
        {el, list} = questions |> List.pop_at(length(questions) - 1)

        [el | list]

      _ ->
        questions
    end
  end
end
