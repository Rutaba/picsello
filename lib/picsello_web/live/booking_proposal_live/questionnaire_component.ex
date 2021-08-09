defmodule PicselloWeb.BookingProposalLive.QuestionnaireComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, Job, Questionnaire.Answer}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_questionnaire()
    |> assign_answer()
    |> assign_validation()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"answers" => params}, %{assigns: %{answer: answer}} = socket) do
    answer = %{answer | answers: update_answers(answer.answers, params)}
    socket |> assign_validation(params) |> assign(answer: answer) |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"answers" => params},
        %{assigns: %{answer: answer}} = socket
      ) do
    case answer
         |> Answer.changeset(%{answers: update_answers(answer.answers, params)})
         |> Repo.insert() do
      {:ok, answer} ->
        send(self(), {:update, %{answer: answer}})

        socket
        |> assign(answer: answer)
        |> close_modal()
        |> noreply()

      _error ->
        socket |> put_flash(:error, "oh no!") |> close_modal() |> noreply()
    end
  end

  defp assign_validation(%{assigns: %{questionnaire: questionnaire}} = socket, params) do
    any_invalid =
      questionnaire.questions
      |> Enum.with_index()
      |> Enum.any?(fn {question, question_index} ->
        !question.optional &&
          Map.get(params, question_index |> Integer.to_string(), [])
          |> reject_blanks()
          |> Enum.empty?()
      end)

    socket |> assign(disable_submit: any_invalid)
  end

  defp assign_validation(%{assigns: %{answer: %{answers: answers}}} = socket) do
    socket
    |> assign_validation(
      for(
        {answer, index} <- answers |> Enum.with_index(),
        do: {index |> Integer.to_string(), answer},
        into: %{}
      )
    )
  end

  defp assign_questionnaire(%{assigns: %{proposal: proposal}} = socket) do
    %{questionnaire: questionnaire} = proposal |> Repo.preload(:questionnaire)
    socket |> assign(questionnaire: questionnaire)
  end

  defp update_answers(answers, params),
    do:
      params
      |> Enum.reduce(answers, fn {question_index, answer}, answers ->
        answers
        |> List.replace_at(question_index |> String.to_integer(), answer |> reject_blanks())
      end)

  defp assign_answer(%{assigns: %{answer: %Answer{}}} = socket), do: socket

  defp assign_answer(
         %{
           assigns: %{
             proposal: %{id: proposal_id},
             questionnaire: %{id: questionnaire_id, questions: questions}
           }
         } = socket
       ) do
    answer =
      case Repo.get_by(Answer, proposal_id: proposal_id) do
        nil ->
          %Answer{
            proposal_id: proposal_id,
            questionnaire_id: questionnaire_id,
            answers: List.duplicate([], Enum.count(questions))
          }

        answer ->
          answer
      end

    socket
    |> assign(answer: answer)
  end

  defp reject_blanks(list), do: list |> Enum.reject(&(String.trim(&1) == ""))
end
