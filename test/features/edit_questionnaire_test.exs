defmodule Picsello.EditQuestionnaireTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  feature "user goes home from questionnaires", %{session: session} do
    session
    |> visit("/questionnaires")
    |> click(css("a[href='/home']", at: 1, count: 3))
    |> assert_path("/home")

    session
    |> visit("/questionnaires")
    |> click(css("a[href='/home']", at: 2, count: 3))
    |> assert_path("/home")
  end

  feature "user sees default questionnaires and it is view only", %{session: session} do
    session
    |> visit("/home")
    |> click(css("[title='Questionnaires']"))
    |> assert_path("/questionnaires")
    |> click(button("Picsello Other Template"))
    |> within_modal(fn modal ->
      modal
      |> assert_text("View questionnaire")
      |> click(button("Close"))
    end)
    |> find(testid("questionnaire-row", count: 5, at: 3), fn row ->
      row
      |> click(css("[phx-hook='Select']"))
      |> assert_text("View")
      |> assert_text("Duplicate")
      |> click(button("View"))
    end)
    |> within_modal(fn modal ->
      modal
      |> assert_text("View Only")
      |> click(button("Close"))
    end)
  end

  feature "user sees default questionnaires and duplicates it", %{session: session} do
    session
    |> visit("/questionnaires")
    |> find(testid("questionnaire-row", count: 5, at: 3), fn row ->
      row
      |> click(css("[phx-hook='Select']"))
      |> click(button("Duplicate"))
    end)
    |> assert_flash(:success, text: "Questionnaire duplicated")
    |> within_modal(fn modal ->
      modal
      |> find(
        text_field("questionnaire_name"),
        &(&1
          |> Element.clear()
          |> Element.fill_in(with: "Custom Other"))
      )
      |> wait_for_enabled_submit_button()
      |> scroll_into_view(testid("question-3"))
      |> assert_value(
        text_field("questionnaire_questions_3_prompt"),
        "How do you want to see these images?"
      )
      |> assert_value(
        select("questionnaire_questions_3_type"),
        "multiselect"
      )
      |> scroll_into_view(testid("question-2"))
      |> find(
        text_field("questionnaire_questions_2_prompt"),
        &(&1 |> Element.clear() |> Element.fill_in(with: "New Prompt"))
      )
      |> find(
        select("questionnaire_questions_2_type"),
        &(&1 |> Element.set_value("phone"))
      )
      |> scroll_into_view(testid("question-1"))
      |> find(testid("question-1"), fn question ->
        question
        |> click(testid("delete-question"))
      end)
    end)
    |> click(button("Save"))
    |> assert_flash(:success, text: "Questionnaire saved")
    |> find(testid("questionnaire-row", count: 6, at: 0), fn row ->
      row
      |> assert_text("Custom Other")
      |> assert_text("3")
    end)
  end

  feature "user creates new questionnaire", %{session: session} do
    session
    |> visit("/questionnaires")
    |> click(button("Create Questionnaire"))
    |> assert_text("Add questionnaire")
    |> within_modal(fn modal ->
      modal
      |> find(
        text_field("questionnaire_name"),
        &(&1
          |> Element.clear()
          |> Element.fill_in(with: "My Favorite Questionnaire"))
      )
      |> click(css("label", text: "Event"))
      |> scroll_into_view(testid("question-0"))
      |> find(
        text_field("questionnaire_questions_0_prompt"),
        &(&1
          |> Element.clear()
          |> Element.fill_in(with: "What is your favorite color?"))
      )
      |> scroll_into_view(testid("add-question"))
      |> click(button("Add question"))
      |> assert_text("Question 2")
      |> scroll_into_view(testid("question-1"))
      |> fill_in(text_field("questionnaire_questions_1_prompt"),
        with: "Testing test test?"
      )
      |> find(
        select("questionnaire_questions_1_type"),
        &(&1 |> Element.set_value("phone"))
      )
      |> find(
        testid("question-1"),
        &(&1 |> click(checkbox("Optional", selected: false)))
      )
      |> scroll_into_view(testid("add-question"))
      |> click(button("Add question"))
      |> scroll_into_view(testid("question-2"))
      |> fill_in(text_field("questionnaire_questions_2_prompt"),
        with: "Testing with multiple options?"
      )
      |> find(
        select("questionnaire_questions_2_type"),
        &(&1 |> Element.set_value("select"))
      )
      |> scroll_into_view(testid("question-option-0"))
      |> find(
        testid("question-2"),
        &(&1
          |> assert_text("Question Answers")
          |> fill_in(text_field("questionnaire[questions][2][options][]"), with: "Option 1")
          |> click(testid("add-option"))
          |> fill_in(text_field("questionnaire[questions][2][options][]", at: 1, count: 2),
            with: "Option 2"
          )
          |> click(css("li button", at: 1, count: 2))
          |> assert_has(css("li", count: 1)))
      )
    end)
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_flash(:success, text: "Questionnaire saved")
    |> find(testid("questionnaire-row", count: 6, at: 0), fn row ->
      row
      |> assert_text("My Favorite Questionnaire")
      |> assert_text("3")
      |> click(button("My Favorite Questionnaire"))
    end)
    |> within_modal(fn modal ->
      modal
      |> scroll_into_view(testid("question-option-0"))
      |> assert_has(css("li", count: 1))
      |> click(button("Cancel"))
    end)
  end

  describe "manages existing questionnaires" do
    setup %{user: user} do
      insert(:questionnaire,
        name: "Custom Other Questionnaire",
        job_type: "other",
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

      :ok
    end

    feature "user edits existing questionnaire by adding, deleting and reordering questions", %{
      session: session
    } do
      session
      |> visit("/questionnaires")
      |> click(button("Custom Other Questionnaire"))
      |> assert_text("Edit questionnaire")
      |> within_modal(fn modal ->
        modal
        |> find(
          text_field("questionnaire_name"),
          &(&1
            |> Element.clear()
            |> Element.fill_in(with: "My Favorite Questionnaire"))
        )
        |> click(css("label", text: "Event"))
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
      |> find(testid("questionnaire-row", count: 6, at: 0), fn row ->
        row
        |> assert_text("3")
      end)
    end

    # feature "user edits existing questionnaire, changes from text to multiselect", %{
    #   session: session
    # } do
    # end

    feature "user duplicates questionnaire from table", %{session: session} do
      session
      |> visit("/questionnaires")
      |> find(testid("questionnaire-row", count: 6, at: 0), fn row ->
        row
        |> click(css("[phx-hook='Select']"))
        |> click(button("Duplicate"))
      end)
      |> assert_flash(:success, text: "Questionnaire duplicated")
      |> click(button("Save"))
      |> assert_flash(:success, text: "Questionnaire saved")
      |> find(testid("questionnaire-row", count: 7, at: 1), fn row ->
        row
        |> assert_text("Copy of Custom Other Questionnaire")
        |> assert_text("1")
      end)
    end

    feature "user deletes questionnaire", %{session: session} do
      session
      |> visit("/questionnaires")
      |> find(testid("questionnaire-row", count: 6, at: 0), fn row ->
        row
        |> click(css("[phx-hook='Select']"))
        |> click(button("Delete"))
      end)
      |> assert_flash(:success, text: "Questionnaire deleted")
    end
  end
end
