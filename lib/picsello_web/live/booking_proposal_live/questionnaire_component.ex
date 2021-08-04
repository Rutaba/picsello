defmodule PicselloWeb.BookingProposalLive.QuestionnaireComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, Job, Questionnaire, Questionnaire.Answer}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_questionnaire()
    |> assign_answer()
    |> ok()
  end

  @impl true
  def handle_event(
        "submit",
        params,
        %{assigns: %{answer: answer}} = socket
      ) do
    answers =
      params
      |> Enum.reduce(answer.answers, fn {question_index, answer}, answers ->
        answers |> List.replace_at(question_index |> String.to_integer(), answer)
      end)

    case answer |> Answer.changeset(%{answers: answers}) |> Repo.insert() do
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

  defp assign_questionnaire(%{assigns: %{job: job}} = socket),
    do: socket |> assign(questionnaire: job |> Questionnaire.for_job() |> Repo.one())

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
end
