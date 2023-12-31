defmodule Mix.Tasks.ImportQuestionnaires do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Questionnaire, Repo}

  @shortdoc "import questionnaires"
  def run(_) do
    load_app()

    questionnaires()
  end

  def questionnaires() do
    [
      %{
        questions: [
          %{prompt: "Fiance / Fiancee full name", type: :text},
          %{prompt: "Fiance Phone", type: :phone},
          %{prompt: "Fiance Email", type: :email},
          %{prompt: "Where is the ceremony being held?", type: :textarea},
          %{
            prompt: "If different from the above, where is your reception being held?",
            type: :textarea,
            optional: true
          },
          %{
            prompt: "Style of wedding",
            type: :multiselect,
            options: [
              "Elegant",
              "Modern",
              "Rustic Vibe",
              "Vintage",
              "Natural / Outdoorsy",
              "DIY",
              "Nerdy"
            ]
          },
          %{
            prompt: "Size of your wedding party",
            type: :select,
            options: [
              "Big - 150+",
              "Average - 100-149",
              "Small - 50-99",
              "Intimate - less than 50"
            ]
          },
          %{
            prompt: "Anything else you think we should know about you and your wedding day?",
            type: :textarea
          }
        ],
        name: "Picsello Wedding Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "wedding"
      },
      %{
        questions: [
          %{
            prompt:
              "Who will we be photographing during our session?  (please include how old the children are). Also, please include everyone that will be in attendance, including any pets!",
            type: :textarea
          },
          %{
            prompt: "Tell us about your family! What do you like to do as a family? Hobbies?",
            type: :textarea
          },
          %{
            prompt:
              "What makes your kids laugh? And we mean really laugh! It can be a silly song, someone dancing, pretending to sneeze. Are your kids physical laughers? Do they really laugh when they are in motion (e.g., being spun around/ lifted in the air or upside down?).",
            type: :textarea
          },
          %{
            prompt: "What are your kids’ favorite things to do? Favorite shows? Songs?",
            type: :textarea
          },
          %{
            prompt:
              "Is there anything we need to know about your kids before we meet at the shoot? For example, do they have sensory issues (e.g., hate grass/sand/itchy clothes)? Do they have visual sensory issues (eg. Hates the camera flash? Do they have sensitive hearing - are they super sensitive to sound, or do they have a hearing impairment)? All of these things help us plan for the best shoot possible for your family.",
            type: :textarea
          },
          %{prompt: "What is your vision for the shoot?", type: :textarea},
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Family Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "family"
      },
      %{
        questions: [
          %{
            prompt:
              "Who will we be photographing during our session?  (please include how old the children are). Also, please include everyone that will be in attendance, including any pets!",
            type: :textarea
          },
          %{
            prompt: "Tell us about your family! What do you like to do as a family? Hobbies?",
            type: :textarea
          },
          %{
            prompt:
              "What makes your kids laugh? And we mean really laugh! It can be a silly song, someone dancing, pretending to sneeze. Are your kids physical laughers? Do they really laugh when they are in motion (e.g., being spun around/ lifted in the air or upside down?).",
            type: :textarea
          },
          %{
            prompt: "What are your kids’ favorite things to do? Favorite shows? Songs?",
            type: :textarea
          },
          %{
            prompt:
              "Is there anything we need to know about your kids before we meet at the shoot? For example, do they have sensory issues (e.g., hate grass/sand/itchy clothes)? Do they have visual sensory issues (eg. Hates the camera flash? Do they have sensitive hearing - are they super sensitive to sound, or do they have a hearing impairment)? All of these things help us plan for the best shoot possible for your family.",
            type: :textarea
          },
          %{
            prompt: "Anything else you think we should know?",
            type: :textarea
          },
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Mini-session Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "mini"
      },
      %{
        questions: [
          %{
            prompt: "Who will we be photographing during our session?",
            type: :textarea
          },
          %{
            prompt: "What is your vision/goals for the shoot?",
            type: :textarea
          },
          %{
            prompt: "Anything else you think we should know?",
            type: :textarea
          },
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Headshot Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "headshot"
      },
      %{
        questions: [
          %{
            prompt: "Who will we be photographing during our session?",
            type: :textarea
          },
          %{
            prompt: "What is your vision/goals for the shoot?",
            type: :textarea
          },
          %{
            prompt: "Anything else you think we should know?",
            type: :textarea
          },
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Portrait Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "portrait"
      },
      %{
        questions: [
          %{
            prompt: "Date of event contact name",
            type: :text
          },
          %{
            prompt: "Phone",
            type: :phone
          },
          %{
            prompt: "Email",
            type: :email
          },
          %{
            prompt: "Where is the event being held?",
            type: :textarea
          },
          %{
            prompt: "Size of your event",
            type: :select,
            options: [
              "Big – 150+",
              "Average – 100-149",
              "Small – 50-99",
              "Intimate – less than 50"
            ]
          },
          %{
            prompt: "Anything else you think we should know about you and your event?",
            type: :textarea
          },
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Event Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "event"
      },
      %{
        questions: [
          %{
            prompt:
              "Who will we be photographing during our session?  (if you have children in the shoot, please include their ages)",
            type: :textarea
          },
          %{
            prompt: "What is your vision/goals for the shoot?",
            type: :textarea
          },
          %{
            prompt:
              "If you have older children coming to the shoot, please fill out the next few questions. What makes your kids laugh? And we mean really laugh! It can be a silly song, someone dancing, pretending to sneeze. Are your kids physical laughers? Do they really laugh when they are in motion (e.g., being spun around/ lifted in the air or upside down?).",
            optional: true,
            type: :textarea
          },
          %{
            prompt: "What are your kids’ favorite things to do? Favorite shows? Songs?",
            optional: true,
            type: :textarea
          },
          %{
            prompt:
              "Is there anything we need to know about your kids before we meet at the shoot? Do they have sensory issues (e.g., hates grass/sand / itchy clothes)? Do they have visual sensory problems (eg. Hates the camera flash?) Do they have sensitive hearing? (are they super sensitive to sound, or do they have hearing impairments?) All of these things help us plan for the best shoot possible for your family.",
            optional: true,
            type: :textarea
          },
          %{prompt: "Anything else you think we should know?", type: :textarea},
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Maternity Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "maternity"
      },
      %{
        questions: [
          %{prompt: "Due date/birth date of the baby", type: :date},
          %{prompt: "Name/gender of the baby", type: :textarea},
          %{
            prompt: "Tell us about your family! What do you like to do as a family? Hobbies?",
            type: :textarea
          },
          %{
            prompt:
              "Who will we be photographing during our session?  (please include how old any other children are)",
            type: :textarea
          },
          %{prompt: "What is your vision for the shoot?", type: :textarea},
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          },
          %{
            prompt:
              "If you have older children coming to the shoot, please fill out the following: What makes your kids laugh? And we mean really laugh!  It can be a silly song, someone dancing, pretending to sneeze. Are your kids physical laughers? Do they really laugh when they are in motion (e.g., being spun around/ lifted in the air or upside down?).",
            type: :textarea,
            optional: true
          },
          %{
            prompt: "What are your kids’ favorite things to do? Favorite shows? Songs?",
            type: :textarea,
            optional: true
          },
          %{
            prompt:
              "Is there anything we need to know about your kids before we meet at the shoot?  Do they have sensory issues (e.g., hates grass/sand / itchy clothes)? Do they have visual sensory problems (eg. hates the camera flash)? Do they have sensitive hearing (are they super sensitive to sound, or are they have hearing impairments? All of these things help us plan for the best shoot possible for your family.",
            type: :textarea,
            optional: true
          }
        ],
        name: "Picsello Newborn Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "newborn"
      },
      %{
        questions: [
          %{
            prompt: "Tell me about your shoot",
            type: :text,
            placeholder: "e.g. Headshot, Birthday party"
          },
          %{
            prompt:
              "Who will we be photographing during our session?  (if you have children in the shoot, please include their ages)",
            type: :textarea
          },
          %{prompt: "What is your vision/goals for the shoot?", type: :textarea},
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Other Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "other"
      },
      %{
        questions: [
          %{
            prompt: "Who will we be photographing during our session?",
            type: :textarea
          },
          %{prompt: "What is your vision/goals for the shoot?", type: :textarea},
          %{
            prompt: "How do you want to see these images?",
            type: :multiselect,
            optional: true,
            options: [
              "Prints",
              "Greeting cards",
              "Albums",
              "Wall Art"
            ]
          }
        ],
        name: "Picsello Boudoir Template",
        is_picsello_default: true,
        is_organizaton_default: false,
        job_type: "boudoir"
      }
    ]
    |> Enum.each(fn attrs ->
      questionnaire =
        Repo.get_by(Questionnaire, job_type: attrs.job_type, is_picsello_default: true)

      if questionnaire do
        questionnaire |> Questionnaire.changeset(attrs) |> Repo.update!()
      else
        Questionnaire.changeset(%Questionnaire{}, attrs) |> Repo.insert!()
      end
    end)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
