defmodule PicselloWeb.BookingProposalLive.QuestionnaireComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, Questionnaire, Questionnaire.Answer}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [questionnaire_item: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_answer()
    |> assign_validation()
    |> ok()
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["Phone", "value"]},
        socket
      ) do
    socket |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        params,
        %{assigns: %{answer: answer}} = socket
      ) do
    params = extract_values(params)
    answer = %{answer | answers: update_answers(answer.answers, params)}
    socket |> assign_validation(params) |> assign(answer: answer) |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        _,
        %{assigns: %{answer: answer}} = socket
      ) do
    case answer
         |> Answer.changeset(%{answers: answer.answers})
         |> Repo.insert() do
      {:ok, answer} ->
        send(self(), {:update, %{answer: answer, next_page: "invoice"}})

        socket
        |> assign(answer: answer)
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

  defp extract_values(%{
         "Phone" => %{"value" => phone},
         "answers" => answer,
         "question_index" => %{"value" => index}
       }) do
    %{"#{index}" => [phone]}
    |> Map.merge(answer)
  end

  defp extract_values(%{"Phone" => %{"value" => phone}, "question_index" => %{"value" => index}}) do
    %{"#{index}" => [phone]}
  end

  defp extract_values(%{"answers" => answer}) do
    answer
  end

  def open_modal_from_proposal(socket, proposal, read_only \\ true) do
    %{
      answer: answer,
      questionnaire: questionnaire,
      job:
        %{
          package: %{organization: %{user: photographer}} = package
        } = job
    } =
      proposal
      |> Repo.preload([:answer, :questionnaire, job: [:client, package: [organization: :user]]])

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || answer != nil,
      job: job,
      package: package,
      answer: answer,
      organization: package.organization,
      questionnaire: questionnaire,
      photographer: photographer,
      proposal: proposal
    })
  end

  def open_modal_from_lead(socket, job, package) do
    questionnaire =
      job
      |> Questionnaire.for_job()
      |> Repo.one!()

    package = package |> Repo.preload([:organization])

    socket
    |> open_modal(__MODULE__, %{
      read_only: true,
      job: job,
      package: package,
      answer: %Answer{
        answers: List.duplicate([], Enum.count(questionnaire.questions))
      },
      organization: package.organization,
      questionnaire: questionnaire,
      photographer: socket.assigns.current_user,
      proposal: nil
    })
  end
end
