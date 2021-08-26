defmodule PicselloWeb.LeadLive.LeadStatusComponentTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias PicselloWeb.LeadLive.LeadStatusComponent

  describe "render" do
    test "when status is :sent", %{} do
      job = insert(:job)
      proposal = insert(:proposal, %{job: job})

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Proposal sent"
      assert component |> Floki.text() =~ "Awaiting acceptance"
    end

    test "when status is :accepted", %{} do
      job = insert(:job)
      proposal = insert(:proposal, %{job: job, accepted_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Proposal accepted"
      assert component |> Floki.text() =~ "Awaiting contract"
    end

    test "when status is :signed and no questionnaire is present", %{} do
      job = insert(:job)
      proposal = insert(:proposal, %{job: job, signed_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :signed and questionnaire is present", %{} do
      job = insert(:job)
      questionnaire = insert(:questionnaire)

      proposal =
        insert(:proposal, %{job: job, questionnaire: questionnaire, signed_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Awaiting questionnaire"
    end

    test "when status is :answered", %{} do
      job = insert(:job)
      questionnaire = insert(:questionnaire)

      proposal =
        insert(:proposal, %{
          job: job,
          questionnaire: questionnaire,
          signed_at: DateTime.utc_now()
        })

      _answer = insert(:answer, proposal: proposal, questionnaire: questionnaire)

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Questionnaire answered"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :deposit_paid", %{} do
      job = insert(:job)
      proposal = insert(:proposal, %{job: job, deposit_paid_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, proposal: proposal)

      assert component |> Floki.text() =~ "Payment paid"
      assert component |> Floki.text() =~ "Job created"
    end
  end
end
