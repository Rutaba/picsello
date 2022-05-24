defmodule PicselloWeb.JobLive.Shared.HistoryComponentTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Picsello.{Repo, Job}
  alias PicselloWeb.JobLive.Shared.HistoryComponent

  describe "render" do
    setup do
      [:lead, :user] |> Enum.map(&{&1, insert(&1)})
    end

    test "when status is :not_sent", %{lead: lead, user: user} do
      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Lead created"
    end

    test "when status is :sent", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead})

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Proposal sent"
      assert component |> Floki.text() =~ "Awaiting acceptance"
    end

    test "when status is :accepted", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead, accepted_at: DateTime.utc_now()})

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Proposal accepted"
      assert component |> Floki.text() =~ "Awaiting contract"
    end

    test "when status is :signed and no questionnaire is present", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead, signed_at: DateTime.utc_now()})

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :signed and questionnaire is present", %{lead: lead, user: user} do
      questionnaire = insert(:questionnaire)

      _proposal =
        insert(:proposal, %{
          job: lead,
          questionnaire: questionnaire,
          signed_at: DateTime.utc_now()
        })

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Proposal signed"
      assert component |> Floki.text() =~ "Awaiting questionnaire"
    end

    test "when status is :answered", %{lead: lead, user: user} do
      questionnaire = insert(:questionnaire)

      proposal =
        insert(:proposal, %{
          job: lead,
          questionnaire: questionnaire,
          signed_at: DateTime.utc_now()
        })

      _answer = insert(:answer, proposal: proposal, questionnaire: questionnaire)

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Questionnaire answered"
      assert component |> Floki.text() =~ "Pending payment"
    end

    test "when status is :archived", %{lead: lead, user: user} do
      lead = lead |> Job.archive_changeset() |> Repo.update!()
      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() =~ "Lead archived"
    end

    test "when status is :deposit_paid", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead})
      insert(:payment_schedule, job: lead, paid_at: DateTime.utc_now())

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() == "Active"
    end

    test "when status is :completed", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead})
      insert(:payment_schedule, job: lead, paid_at: DateTime.utc_now())
      lead = lead |> Job.complete_changeset() |> Repo.update!()

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() == "Completed"
    end

    test "when status is :imported", %{lead: lead, user: user} do
      _proposal = insert(:proposal, %{job: lead})
      package = insert(:package, user: user, collected_price: 0)
      lead = lead |> Job.add_package_changeset(%{package_id: package.id}) |> Repo.update!()

      component = render_component(HistoryComponent, job: lead, current_user: user)

      assert component |> Floki.text() == "Active"
    end
  end
end
