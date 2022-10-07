defmodule PicselloWeb.Live.Questionnaires.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Questionnaire}
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:questionnaire, %Questionnaire{
      job_type: "other",
      organization_id: socket.assigns.current_user.organization_id,
      questions: [
        %{
          prompt: "Tell me about your shoot",
          type: :text,
          placeholder: "e.g. Headshot, Birthday party"
        }
      ]
    })
    |> assign(:questionnaires, [])
    |> ok()
  end

  @impl true
  def handle_info({:update, _questionnaire}, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event("create-questionnaire", %{}, socket) do
    socket
    |> PicselloWeb.QuestionnaireFormComponent.open(
      Map.take(socket.assigns, [:questionnaire, :current_user])
    )
    |> noreply()
  end
end
