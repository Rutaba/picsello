defmodule PicselloWeb.LeadLive.LeadStatusComponentTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias PicselloWeb.LeadLive.LeadStatusComponent

  describe "render" do
    setup do
      [job: insert(:job), user: insert(:user)]
    end

    test "when status is :not_sent", %{job: job, user: user} do
      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Lead created"
    end

    test "when status is :sent", %{job: job, user: user} do
      _proposal = insert(:proposal, %{job: job})

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Proposal sent"
      assert component |> Floki.text() =~ "Awaiting acceptance"
    end

    test "when status is :accepted", %{job: job, user: user} do
      _proposal = insert(:proposal, %{job: job, accepted_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Proposal accepted"
      assert component |> Floki.text() =~ "Awaiting contract"
    end

    test "when status is :signed and no questionnaire is present", %{job: job, user: user} do
      _proposal = insert(:proposal, %{job: job, signed_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :signed and questionnaire is present", %{job: job, user: user} do
      questionnaire = insert(:questionnaire)

      _proposal =
        insert(:proposal, %{job: job, questionnaire: questionnaire, signed_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Awaiting questionnaire"
    end

    test "when status is :answered", %{job: job, user: user} do
      questionnaire = insert(:questionnaire)

      proposal =
        insert(:proposal, %{
          job: job,
          questionnaire: questionnaire,
          signed_at: DateTime.utc_now()
        })

      _answer = insert(:answer, proposal: proposal, questionnaire: questionnaire)

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Questionnaire answered"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :deposit_paid", %{job: job, user: user} do
      _proposal = insert(:proposal, %{job: job, deposit_paid_at: DateTime.utc_now()})

      component = render_component(LeadStatusComponent, job: job, current_user: user)

      assert component |> Floki.text() =~ "Payment paid"
      assert component |> Floki.text() =~ "Job created"
    end
  end
end
