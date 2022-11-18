defmodule Picsello.QuestionnaireTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Repo, Questionnaire, Job, Package}

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  describe "for_job when template is not set" do
    test "when job type is different than other" do
      assert %{job_type: "family"} =
               Questionnaire.for_job(%Job{
                 type: "family",
                 package: %Package{questionnaire_template_id: nil}
               })
               |> Repo.one()
    end

    test "when job type is other" do
      assert %{job_type: "other"} =
               Questionnaire.for_job(%Job{
                 type: "other",
                 package: %Package{questionnaire_template_id: nil}
               })
               |> Repo.one()
    end

    test "when job type doesn't exist then falls back to other" do
      assert %{job_type: "other"} =
               Questionnaire.for_job(%Job{
                 type: "event",
                 package: %Package{questionnaire_template_id: nil}
               })
               |> Repo.one()
    end
  end

  describe "for_job when template is set" do
    setup do
      questionnaire =
        insert(:questionnaire,
          job_type: "family",
          questions: [
            %{
              type: "textarea",
              prompt: "What do you like to do as a family?",
              optional: false
            }
          ]
        )

      [questionnaire: questionnaire]
    end

    test "when questionnaire template id is set", %{questionnaire: questionnaire} do
      assert %{job_type: "family"} =
               Questionnaire.for_job(%Job{
                 package: %Package{questionnaire_template_id: questionnaire.id}
               })
               |> Repo.one()
    end

    test "when questionnaire template id is set but package job_type is different", %{
      questionnaire: questionnaire
    } do
      assert %{job_type: "family"} =
               Questionnaire.for_job(%Job{
                 package: %Package{job_type: "other", questionnaire_template_id: questionnaire.id}
               })
               |> Repo.one()
    end
  end

  describe "for_package when template is not set" do
    test "when job type is different than other" do
      assert %{job_type: "family"} =
               Questionnaire.for_package(%Package{
                 job_type: "family",
                 questionnaire_template_id: nil
               })
    end

    test "when job type is other" do
      assert %{job_type: "other"} =
               Questionnaire.for_package(%Package{
                 job_type: "other",
                 questionnaire_template_id: nil
               })
    end

    test "when job type doesn't exist then falls back to other" do
      assert %{job_type: "other"} =
               Questionnaire.for_package(%Package{
                 job_type: "event",
                 questionnaire_template_id: nil
               })
    end
  end

  describe "for_package when template is set" do
    setup do
      questionnaire =
        insert(:questionnaire,
          job_type: "event",
          questions: [
            %{
              type: "textarea",
              prompt: "What is the vibe of your upcoming event?",
              optional: false
            }
          ]
        )

      [questionnaire: questionnaire]
    end

    test "when questionnaire template id is set", %{questionnaire: questionnaire} do
      assert %{job_type: "event"} =
               Questionnaire.for_package(%Package{
                 job_type: "event",
                 questionnaire_template_id: questionnaire.id
               })
    end

    test "when questionnaire template id is set but package job_type is different", %{
      questionnaire: questionnaire
    } do
      assert %{job_type: "event"} =
               Questionnaire.for_package(%Package{
                 job_type: "other",
                 questionnaire_template_id: questionnaire.id
               })
    end
  end

  describe "for_organization" do
    setup do
      organization = insert(:organization)
      user = insert(:user, organization: organization, name: "Jane Doe")
      package = insert(:package, organization: organization)

      [organization: organization, user: user, package: package]
    end

    test "check if org can see default questionnaires", %{organization: organization} do
      assert [
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               }
             ] = Questionnaire.for_organization(organization.id)
    end

    test "check if org can see their questionnaires that don't have package_ids", %{
      organization: organization,
      package: package
    } do
      # belongs to a package that has been copied
      insert(:questionnaire,
        name: "Event Questionnaire",
        job_type: "event",
        is_organization_default: false,
        organization_id: organization.id,
        package_id: package.id,
        questions: [
          %{
            type: "textarea",
            prompt: "What is the vibe of your upcoming event?",
            optional: false
          }
        ]
      )

      # no package_id
      insert(:questionnaire,
        name: "Event Questionnaire 2",
        job_type: "event",
        is_organization_default: false,
        organization_id: organization.id,
        package_id: nil,
        questions: [
          %{
            type: "textarea",
            prompt: "What is the vibe of your upcoming event?",
            optional: false
          }
        ]
      )

      assert [
               %Picsello.Questionnaire{
                 is_picsello_default: false
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true
               }
             ] = Questionnaire.for_organization(organization.id)
    end
  end

  describe "for_organization_by_job_type" do
    setup do
      organization = insert(:organization)

      insert(:questionnaire,
        name: "Custom Other Questionnaire",
        job_type: "other",
        is_organization_default: false,
        organization_id: organization.id,
        package_id: nil,
        questions: [
          %{
            type: "textarea",
            prompt: "What is the vibe?",
            optional: false
          }
        ]
      )

      [organization: organization]
    end

    test "when job type is nil", %{organization: organization} do
      assert [
               %Picsello.Questionnaire{
                 job_type: "other",
                 name: "Custom Other Questionnaire"
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true,
                 job_type: "other"
               }
             ] = Questionnaire.for_organization_by_job_type(organization.id, nil)
    end

    test "when job type is not nil", %{organization: organization} do
      assert [
               %Picsello.Questionnaire{
                 job_type: "other",
                 name: "Custom Other Questionnaire"
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true,
                 job_type: "family"
               },
               %Picsello.Questionnaire{
                 is_picsello_default: true,
                 job_type: "other"
               }
             ] = Questionnaire.for_organization_by_job_type(organization.id, "family")
    end
  end

  describe "delete_ and get_ one" do
    setup do
      questionnaire =
        insert(:questionnaire,
          job_type: "newborn",
          questions: [
            %{
              type: "text",
              prompt: "When are you due?",
              optional: false
            }
          ]
        )

      [questionnaire: questionnaire]
    end

    test "get_questionnaire_by_id", %{questionnaire: questionnaire} do
      assert %{
               job_type: "newborn",
               is_picsello_default: false,
               questions: [%{prompt: "When are you due?"}]
             } = Questionnaire.get_questionnaire_by_id(questionnaire.id)
    end

    test "delete_questionnaire_by_id", %{questionnaire: questionnaire} do
      assert {1, nil} = Questionnaire.delete_questionnaire_by_id(questionnaire.id)
    end
  end

  describe "clean_questionnaire_for_changeset" do
    setup do
      organization = insert(:organization)
      user = insert(:user, organization: organization, name: "Jane Doe")
      package = insert(:package, organization: organization)

      questionnaire =
        insert(:questionnaire,
          name: "Event Questionnaire",
          job_type: "event",
          is_picsello_default: false,
          is_organization_default: false,
          organization_id: organization.id,
          package_id: nil,
          questions: [
            %{
              type: "textarea",
              prompt: "What is the vibe of your upcoming event?",
              optional: false
            },
            %{
              type: "multiselect",
              prompt: "How do you want your images?",
              optional: false,
              options: ["Prints", "Digital"]
            }
          ]
        )

      [questionnaire: questionnaire, package: package, user: user]
    end

    test "without package_id", %{questionnaire: questionnaire, user: user} do
      assert %{
               id: nil,
               inserted_at: nil,
               is_organization_default: false,
               is_picsello_default: false,
               job_type: "event",
               name: "Event Questionnaire",
               package_id: nil,
               questions: [
                 %{
                   optional: false,
                   options: [],
                   placeholder: nil,
                   prompt: "What is the vibe of your upcoming event?",
                   type: :textarea
                 },
                 %{
                   optional: false,
                   options: ["Prints", "Digital"],
                   placeholder: nil,
                   prompt: "How do you want your images?",
                   type: :multiselect
                 }
               ],
               updated_at: nil
             } = Questionnaire.clean_questionnaire_for_changeset(questionnaire, user)
    end

    test "with package_id", %{questionnaire: questionnaire, user: user, package: package} do
      assert %{
               id: nil,
               inserted_at: nil,
               is_organization_default: false,
               is_picsello_default: false,
               job_type: "event",
               name: "Event Questionnaire",
               questions: [
                 %{
                   optional: false,
                   options: [],
                   placeholder: nil,
                   prompt: "What is the vibe of your upcoming event?",
                   type: :textarea
                 },
                 %{
                   optional: false,
                   options: ["Prints", "Digital"],
                   placeholder: nil,
                   prompt: "How do you want your images?",
                   type: :multiselect
                 }
               ],
               updated_at: nil
             } = Questionnaire.clean_questionnaire_for_changeset(questionnaire, user, package.id)
    end
  end
end
