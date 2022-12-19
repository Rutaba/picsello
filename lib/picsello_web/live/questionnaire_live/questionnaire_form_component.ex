defmodule PicselloWeb.QuestionnaireFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Questionnaire, Repo}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

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
      <.close_x />

      <div class="sm:flex items-center gap-4">
      <.step_heading state={@state} />
        <%= if @state === nil do %>
          <div><.badge color={:gray}>View Only</.badge></div>
        <% end %>
      </div>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <h2 class="text-2xl leading-6 text-gray-900 mb-8 font-bold">Details</h2>

        <div class={classes("", %{"grid gap-3" => @state == :edit_lead})}>
          <%= if @state == :edit_lead do %>
            <div class="flex flex-col">
              <label class="input-label">Select template to reset questions</label>
              <%= select f, :change_template, template_options(@current_user.organization_id), selected: "", class: "select", disabled: @state === nil %>
              <%= hidden_input f, :name, label: "Name" %>
            </div>
          <% else %>
            <%= labeled_input f, :name, label: "Name", disabled: @state === nil %>
          <% end %>
        </div>

        <div class={classes("mt-8", %{"hidden" => @state == :edit_lead})}>
          <%= label_for f, :type, label: "Type of Photography (select Other to use for all types)" %>
          <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
            <%= for job_type <- @job_types do %>
              <.job_type_option type="radio" name={input_name(f, :job_type)} job_type={job_type} checked={input_value(f, :job_type) == job_type} disabled={@state === nil} />
            <% end %>
          </div>
        </div>

        <hr class="my-8" />

        <h2 class="text-2xl leading-6 text-gray-900 mb-8 font-bold">Questions</h2>

        <fieldset>
          <%= for f_questions <- inputs_for(f, :questions) do %>
            <div class="mb-8 border rounded-lg" {testid("question-#{f_questions.index}")}>
              <%= hidden_inputs_for(f_questions) %>
              <%= if @state !== nil do %>
              <div class="flex items-center justify-between bg-gray-100 p-4 rounded-t-lg">
                <div>
                  <h3 class="text-lg font-bold">Question <%= f_questions.index + 1 %></h3>
                </div>
                <div class="flex items-center gap-4">
                  <button class="bg-red-sales-100 border border-red-sales-300 hover:border-transparent rounded-lg flex items-center p-2" type="button" phx-click="delete-question" phx-target={@myself} phx-value-id={f_questions.index} {testid("delete-question")}>
                    <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
                  </button>
                  <button class={classes("bg-white border hover:border-white rounded-lg flex items-center p-2", %{"pointer-events-none hover:border opacity-40 cursor-disabled" => questions_length(f) === f_questions.index + 1})} type="button" phx-click="reorder-question" phx-target={@myself} phx-value-direction="down" phx-disable-with={questions_length(f) === f_questions.index + 1} disabled={questions_length(f) === f_questions.index + 1} {testid("reorder-question-down")}>
                    <.icon name="down" class="inline-block w-4 h-4 stroke-current stroke-3 text-black" />
                  </button>
                  <button class={classes("bg-white border hover:border-white rounded-lg flex items-center p-2", %{"pointer-events-none hover:border opacity-40 cursor-disabled" => f_questions.index === 0})} type="button" phx-click="reorder-question" phx-target={@myself} phx-value-direction="up" phx-disable-with={f_questions.index === 0} disabled={f_questions.index === 0} {testid("reorder-question-up")}>
                    <.icon name="up" class="inline-block w-4 h-4 stroke-current stroke-3 text-black" />
                  </button>
                </div>
              </div>
              <% end %>
              <div class="p-4">
                <div class="grid sm:grid-cols-3 gap-6">
                  <%= labeled_input f_questions, :prompt, phx_debounce: 200, label: "What question would you like to ask your client?", type: :textarea, placeholder: "Enter the question you'd like to ask…", disabled: @state === nil, wrapper_class: "sm:col-span-2" %>
                  <label class="flex items-center mt-6 sm:mt-8 justify-self-start sm:col-span-1 cursor-pointer font-bold" {testid("question-optional")}>
                    <%= checkbox f_questions, :optional, class: "w-5 h-5 mr-2 checkbox", disabled: @state === nil %>
                    Optional <em class="font-normal">(your client can skip this question)</em>
                  </label>
                </div>
                <div class="flex flex-col mt-6">
                  <%= label_for f_questions, :type, label: "What type of question is this? Text, checkboxes, etc" %>
                  <%= select f_questions, :type, field_options(), class: "select", disabled: @state === nil, phx_target: @myself, phx_value_id: f_questions.index %>
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

        <%= if @state !== nil do %>
        <div class="mt-8">
          <.icon_button {testid("add-question")} phx-click="add-question" phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add question" color="blue-planning-300" icon="plus">
            Add question
          </.icon_button>
        </div>
        <% end %>

        <.footer>
          <%= if @state !== nil do %>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>
          <% end %>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            <%= if @state === nil do %>Close<% else %>Cancel<% end %>
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
      :edit -> "Edit questionnaire"
      :edit_lead -> "Edit questionnaire"
      :create -> "Add questionnaire"
      _ -> "View questionnaire template"
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
  def handle_event(
        "add-question",
        %{},
        %{assigns: %{questionnaire: questionnaire, changeset: changeset}} = socket
      ) do
    questions =
      changeset
      |> Ecto.Changeset.get_field(:questions)
      |> Enum.map(&Map.from_struct/1)
      |> List.insert_at(-1, %{
        optional: false,
        options: [],
        placeholder: nil,
        prompt: nil,
        type: :text
      })

    socket
    |> assign_changeset(
      merge_changes(questions, changeset),
      insert_or_update?(questionnaire)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "reorder-question",
        %{"direction" => direction},
        %{assigns: %{questionnaire: questionnaire, changeset: changeset}} = socket
      ) do
    questions =
      changeset
      |> Ecto.Changeset.get_field(:questions)
      |> Enum.map(&Map.from_struct/1)
      |> swap(direction)

    socket
    |> assign_changeset(
      merge_changes(questions, changeset),
      insert_or_update?(questionnaire)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-question",
        %{"id" => id},
        %{assigns: %{questionnaire: questionnaire, changeset: changeset}} = socket
      ) do
    index = String.to_integer(id)

    questions =
      changeset
      |> Ecto.Changeset.get_field(:questions)
      |> Enum.map(&Map.from_struct/1)
      |> List.delete_at(index)

    socket
    |> assign_changeset(
      merge_changes(questions, changeset),
      insert_or_update?(questionnaire)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-option",
        %{"id" => id},
        %{assigns: %{questionnaire: questionnaire, changeset: changeset}} = socket
      ) do
    index = String.to_integer(id)

    questions =
      changeset
      |> Ecto.Changeset.get_field(:questions)
      |> Enum.map(&Map.from_struct/1)
      |> List.update_at(index, fn question ->
        question |> Map.put(:options, (question.options || []) ++ [nil])
      end)

    socket
    |> assign_changeset(
      merge_changes(questions, changeset),
      insert_or_update?(questionnaire)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-option",
        %{"id" => id, "option-id" => option_id},
        %{assigns: %{questionnaire: questionnaire, changeset: changeset}} = socket
      ) do
    index = String.to_integer(id)
    option_id = String.to_integer(option_id)

    questions =
      changeset
      |> Ecto.Changeset.get_field(:questions)
      |> Enum.map(&Map.from_struct/1)
      |> List.update_at(index, fn question ->
        question |> Map.put(:options, List.delete_at(question.options, option_id))
      end)

    socket
    |> assign_changeset(
      merge_changes(questions, changeset),
      insert_or_update?(questionnaire)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"questionnaire" => %{"change_template" => change_template}},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    selected_template =
      case change_template do
        "blank" ->
          %{
            name: "Custom",
            questions: []
          }

        _ ->
          questionnaire =
            Questionnaire.get_questionnaire_by_id(change_template |> String.to_integer())

          questions =
            questionnaire.questions
            |> Enum.map(fn question ->
              question |> Map.from_struct() |> Map.drop([:id])
            end)

          %{
            name: questionnaire.name,
            questions: questions
          }
      end

    socket
    |> assign_changeset(
      merge_changes(selected_template.name, selected_template.questions, changeset),
      :validate
    )
    |> noreply()
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
        send(socket.parent_pid, {:update, %{questionnaire: questionnaire}})

        socket |> close_modal()

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  defp options_editor(assigns) do
    ~H"""
    <div class="mt-6">
      <h4 class="mb-1 input-label">Question Answers</h4>
      <ul class="mb-6">
        <%= for {option, index} <- input_value(@f_questions, :options) |> Enum.with_index() do %>
          <li class="mb-2 flex items-center gap-2" {testid("question-option-#{index}")}>
            <input type="text" class="text-input" name={"questionnaire[questions][#{@f_questions.index}][options][]"} value={option} placeholder="Enter an option…" disabled={@state === nil} />
            <%= if @state !== nil do %>
            <button class="bg-red-sales-100 border border-red-sales-300 hover:border-transparent rounded-lg flex items-center p-2" type="button" phx-click="delete-option" phx-value-id={@f_questions.index} phx-value-option-id={index} phx-target={@myself}>
              <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
            </button>
            <% end %>
          </li>
        <% end %>
      </ul>
      <%= if @state !== nil do %>
      <.icon_button {testid("add-option")} phx-click="add-option" phx-value-id={@f_questions.index} phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add question option" color="blue-planning-300" icon="plus">
        Add option
      </.icon_button>
      <% end %>
    </div>
    """
  end

  defp save_questionnaire(params, %{
         assigns: %{questionnaire: %{id: nil} = questionnaire, state: state}
       }) do
    questionnaire
    |> Map.drop([:organization])
    |> Map.put(:questions, [])
    |> Questionnaire.changeset(params, state)
    |> Repo.insert_or_update()
  end

  defp save_questionnaire(params, %{
         assigns: %{questionnaire: questionnaire, state: state}
       }) do
    questionnaire
    |> Map.drop([:organization])
    |> Questionnaire.changeset(params, state)
    |> Repo.insert_or_update()
  end

  defp assign_changeset(
         %{assigns: %{questionnaire: %{id: nil} = questionnaire, state: state}} = socket,
         params,
         action
       ) do
    attrs = params

    changeset =
      questionnaire
      |> Map.put(:questions, [])
      |> maybe_duplicate_questions?(questionnaire, attrs, state)
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
  end

  defp assign_changeset(
         %{assigns: %{questionnaire: questionnaire, state: state}} = socket,
         params,
         action
       ) do
    attrs = params

    changeset =
      questionnaire
      |> Questionnaire.changeset(attrs, state)
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
  end

  defp maybe_duplicate_questions?(questionnaire, original_questionnaire, attrs, state) do
    case attrs do
      %{"questions" => _} ->
        Questionnaire.changeset(questionnaire, attrs, state)

      %{questions: _} ->
        Questionnaire.changeset(questionnaire, attrs, state)

      _ ->
        Questionnaire.changeset(questionnaire, attrs, state)
        |> Ecto.Changeset.put_change(
          :questions,
          original_questionnaire.questions
        )
    end
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
      {"Select (radio buttons, client picks one)", :select},
      {"Date (date picker)", :date},
      {"Multiselect (checkboxes, client picks multiple)", :multiselect},
      {"Phone", :phone},
      {"Email", :email}
    ]
  end

  defp template_options(current_user) do
    questionnaires =
      Questionnaire.for_organization(current_user)
      |> Enum.map(fn q -> [key: q.name, value: q.id] end)

    [
      [key: "select a template to reset", value: "", disabled: true],
      [key: "Blank questionnaire", value: "blank"]
    ] ++ questionnaires
  end

  defp insert_or_update?(%{id: _}), do: :update

  defp insert_or_update?(_), do: :insert

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

  defp merge_changes(questions, changeset) do
    Map.merge(%{questions: questions}, changeset.changes |> Map.drop([:questions]))
  end

  defp merge_changes(name, questions, changeset) do
    Map.merge(
      %{name: name, questions: questions},
      changeset.changes |> Map.drop([:name, :questions])
    )
  end

  defp questions_length(f), do: length(inputs_for(f, :questions))
end
