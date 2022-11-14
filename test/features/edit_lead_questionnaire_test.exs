defmodule Picsello.EditLeadQuestionnaireTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, Organization}

  @edit_questionnaire_button testid("edit-questionnaire")

  setup :onboarded
  setup :authenticated

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  setup %{user: user} do
    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    wedding_lead =
      insert(:lead, %{
        type: "wedding",
        user: user,
        client: %{name: "John"},
        shoots: [
          %{
            name: "Shoot 1",
            address: "320 1st st",
            starts_at: ~U[2029-09-30 19:00:00Z],
            duration_minutes: 15
          },
          %{
            name: "Shoot 2",
            address: "320 1st st",
            starts_at: ~U[2029-09-30 19:00:00Z],
            duration_minutes: 15
          }
        ]
      })

    headshot_lead =
      insert(:lead, %{
        type: "headshot",
        user: user
      })

    insert(:email_preset, job_type: wedding_lead.type, state: :booking_proposal)
    insert(:email_preset, job_type: headshot_lead.type, state: :booking_proposal)

    [wedding_lead: wedding_lead, headshot_lead: headshot_lead]
  end

  feature "user sees message when package is missing", %{
    session: session,
    wedding_lead: wedding_lead
  } do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, wedding_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("You haven’t selected a package yet.")
    end)
  end

  feature "user sees default questionnaire was used for wedding job type", %{
    session: session,
    wedding_lead: wedding_lead,
    user: user
  } do
    insert_package(user, wedding_lead)

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, wedding_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("Selected questionnaire: Picsello Default Questionnaire")
      |> click(@edit_questionnaire_button)
    end)
    |> assert_text("Edit questionnaire")
    |> assert_text("Fiance / Fiancee full name")
  end

  feature "user sees default questionnaire was used for other job type", %{
    session: session,
    headshot_lead: headshot_lead,
    user: user
  } do
    insert_package(user, headshot_lead, "headshot")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, headshot_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("Selected questionnaire: Picsello Default Questionnaire")
      |> click(@edit_questionnaire_button)
    end)
    |> assert_text("Edit questionnaire")
    |> assert_text("Who will we be photographing during our session?")
  end

  feature "user sees selected questionnaire from package template", %{
    session: session,
    headshot_lead: headshot_lead,
    user: user
  } do
    custom_questionnaire = insert_questionnaire(user)
    insert_package(user, headshot_lead, "headshot", custom_questionnaire.id)

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, headshot_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("Selected questionnaire: My Custom Questionnaire")
      |> click(@edit_questionnaire_button)
    end)
    |> assert_text("Edit questionnaire")
    |> assert_text("What is the vibe?")
  end

  feature "user edits questionnaire from package template", %{
    session: session,
    headshot_lead: headshot_lead,
    user: user
  } do
    custom_questionnaire = insert_questionnaire(user)
    insert_package(user, headshot_lead, "headshot", custom_questionnaire.id)

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, headshot_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("Selected questionnaire: My Custom Questionnaire")
      |> click(@edit_questionnaire_button)
    end)
    |> assert_text("Edit questionnaire")
    |> within_modal(fn modal ->
      modal
      |> scroll_into_view(testid("add-question"))
      |> click(button("Add question"))
      |> assert_text("Question 2")
      |> scroll_into_view(testid("question-1"))
      |> fill_in(text_field("questionnaire_questions_1_prompt"),
        with: "Testing test test?"
      )
      |> find(
        select("questionnaire_questions_1_type"),
        &(&1 |> Element.set_value("multiselect"))
      )
      |> scroll_into_view(testid("question-option-0"))
      |> find(
        testid("question-1"),
        &(&1
          |> assert_text("Question Answers")
          |> click(testid("add-option"))
          |> fill_in(text_field("questionnaire[questions][1][options][]"), with: "Option 1")
          |> click(testid("add-option"))
          |> fill_in(text_field("questionnaire[questions][1][options][]", at: 1, count: 2),
            with: "Option 2"
          )
          |> assert_has(css("li", count: 2)))
      )
      |> find(
        select("questionnaire_questions_1_type"),
        &(&1 |> Element.set_value("phone"))
      )
      |> scroll_into_view(testid("add-question"))
      |> click(button("Add question"))
      |> assert_text("Question 3")
      |> scroll_into_view(testid("question-3"))
      |> fill_in(text_field("questionnaire_questions_2_prompt"),
        with: "Started 3rd, should be second"
      )
      |> find(
        testid("question-2"),
        &(&1
          |> click(testid("reorder-question-up")))
      )
      |> scroll_into_view(testid("question-1"))
      |> assert_value(
        text_field("questionnaire_questions_1_prompt"),
        "Started 3rd, should be second"
      )
      |> scroll_into_view(testid("question-0"))
      |> find(
        testid("question-0"),
        &(&1
          |> click(testid("reorder-question-down")))
      )
      |> scroll_into_view(testid("question-1"))
      |> assert_value(
        text_field("questionnaire_questions_1_prompt"),
        "Testing test test?"
      )
      |> scroll_into_view(testid("add-question"))
      |> click(button("Add question"))
      |> assert_text("Question 4")
      |> scroll_into_view(testid("question-3"))
      |> find(
        testid("question-3"),
        &(&1
          |> click(testid("delete-question")))
      )
    end)
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_flash(:success, text: "Questionnaire saved")
    |> click(@edit_questionnaire_button)
    |> find(
      select("questionnaire_change_template"),
      &(&1 |> Element.set_value("blank"))
    )
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_flash(:success, text: "Questionnaire saved")
  end

  # this test is needed to check if leads in a created state before this feature is launched can open the new modal without error
  feature "user views already created lead without a template id", %{
    session: session,
    wedding_lead: wedding_lead,
    user: user
  } do
    insert_package(user, wedding_lead, "wedding")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, wedding_lead.id))
    |> find(testid("questionnaire"), fn element ->
      element
      |> assert_text("Selected questionnaire: Picsello Default Questionnaire")
      |> click(@edit_questionnaire_button)
    end)
    |> assert_text("Edit questionnaire")
  end

  feature "user views sent booking proposal questionnaire without a template id", %{
    session: session,
    wedding_lead: wedding_lead,
    user: user
  } do
    insert_package(user, wedding_lead, "wedding")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, wedding_lead.id))
    |> click(button("Send proposal", count: 2, at: 1))
    |> wait_for_enabled_submit_button()
    |> click(button("Send Email"))
  end

  defp insert_questionnaire(user) do
    insert(:questionnaire,
      name: "My Custom Questionnaire",
      job_type: "headshot",
      is_picsello_default: false,
      is_organization_default: false,
      organization_id: user.organization.id,
      package_id: nil,
      questions: [
        %{
          type: "textarea",
          prompt: "What is the vibe?",
          optional: false
        }
      ]
    )
  end

  defp insert_package(user, lead, job_type \\ "wedding", questionnaire_id \\ nil) do
    package =
      insert(:package, %{
        user: user,
        job_type: job_type,
        questionnaire_template_id: questionnaire_id
      })

    lead
    |> Picsello.Job.add_package_changeset(%{
      package_id: package.id
    })
    |> Picsello.Repo.update!()

    package
  end
end
