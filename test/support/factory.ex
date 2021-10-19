defmodule Picsello.Factory do
  @moduledoc """
  test helpers for creating job entities
  """

  use ExMachina.Ecto, repo: Picsello.Repo

  alias Picsello.{
    BookingProposal,
    Client,
    Job,
    Organization,
    Package,
    ClientMessage,
    Repo,
    Shoot,
    Accounts.User,
    Questionnaire,
    Questionnaire.Answer
  }

  def valid_user_password(), do: "hello world!"

  def extract_user_token(fun) do
    {:ok, email} = fun.(&"[TOKEN]#{&1}[TOKEN]")

    case email do
      %{private: %{send_grid_template: %{dynamic_template_data: %{"url" => url}}}} -> url
      %{text_body: body} -> body
    end
    |> String.split("[TOKEN]")
    |> Enum.at(1)
  end

  def email_substitutions(%Bamboo.Email{
        private: %{send_grid_template: %{dynamic_template_data: substitutions}}
      }),
      do: substitutions

  def user_factory do
    %User{}
    |> User.registration_changeset(valid_user_attributes())
    |> Ecto.Changeset.apply_changes()
  end

  def onboard!(%User{} = user) do
    user
    |> User.complete_onboarding_changeset()
    |> Repo.update!()
  end

  def valid_user_attributes(attrs \\ %{}),
    do:
      attrs
      |> Enum.into(%{
        email: sequence(:email, &"user-#{&1}@example.com"),
        password: valid_user_password(),
        name: "Mary Jane",
        time_zone: "Etc/GMT",
        organization: fn -> params_for(:organization) end
      })
      |> evaluate_lazy_attributes()

  def unique_user_email(), do: valid_user_attributes() |> Map.get(:email)

  def organization_factory do
    %Organization{name: "Camera User Group"}
  end

  def package_factory(attrs) do
    %Package{
      base_price: 10,
      download_count: 0,
      download_each_price: 0,
      name: "Package name",
      description: "Package description",
      shoot_count: 2,
      organization: fn ->
        case attrs do
          %{user: user} -> user |> Repo.preload(:organization) |> Map.get(:organization)
          _ -> build(:organization)
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:user]))
    |> evaluate_lazy_attributes()
  end

  def client_factory(attrs) do
    %Client{
      email: sequence(:email, &"client-#{&1}@example.com"),
      name: "Mary Jane",
      phone: "(904) 555-5555",
      organization: fn ->
        case attrs do
          %{user: user} -> user |> Repo.preload(:organization) |> Map.get(:organization)
          _ -> build(:organization)
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:user]))
    |> evaluate_lazy_attributes()
  end

  def shoot_factory do
    %Shoot{
      duration_minutes: 15,
      location: "home",
      name: "chute",
      starts_at: DateTime.utc_now()
    }
  end

  def questionnaire_factory(attrs) do
    %Questionnaire{
      questions: [
        %Questionnaire.Question{
          type: "multiselect",
          prompt: "Who is the baby's daddy?",
          options: ["I don't know", "My partner"],
          optional: true
        },
        %Questionnaire.Question{
          type: "text",
          prompt: "why?",
          optional: false
        },
        %Questionnaire.Question{
          type: "select",
          prompt: "Do you agree?",
          options: ["Of course", "Nope"],
          optional: true
        },
        %Questionnaire.Question{
          type: "textarea",
          prompt: "Describe it",
          optional: false
        },
        %Questionnaire.Question{
          type: "date",
          prompt: "When",
          optional: false
        },
        %Questionnaire.Question{
          type: "email",
          prompt: "Email",
          optional: false
        },
        %Questionnaire.Question{
          type: "phone",
          prompt: "Phone",
          optional: false
        }
      ],
      job_type: "newborn"
    }
    |> merge_attributes(attrs)
  end

  def answer_factory(attrs) do
    %Answer{
      answers: [["1"], ["2"], ["3"], ["4"], ["5"], ["6"], ["7"]]
    }
    |> merge_attributes(attrs)
  end

  def proposal_factory(attrs) do
    %BookingProposal{job: fn -> build(:lead) end}
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def client_message_factory(attrs) do
    %ClientMessage{
      subject: "here is what i propose",
      body_text: "lets take some pictures!",
      body_html: "lets take <i>some</i> <b>pictures!</b>"
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def promote_to_job(%Job{package_id: nil, client: %{organization: organization}} = job)
      when not is_nil(organization) do
    job
    |> Job.add_package_changeset(%{
      package_id: insert(:package, organization: organization).id
    })
    |> Repo.update!()
    |> promote_to_job()
  end

  def promote_to_job(%Job{} = job) do
    %{package: %{shoot_count: shoot_count}, shoots: shoots} =
      Repo.preload(job, [:package, :shoots], force: true)

    insert(:proposal,
      job: job,
      deposit_paid_at: DateTime.utc_now(),
      accepted_at: DateTime.utc_now(),
      signed_at: DateTime.utc_now()
    )

    insert_list(shoot_count - Enum.count(shoots), :shoot, job: job)

    job |> Repo.preload(:shoots, force: true)
  end

  def lead_factory(attrs) do
    user_attr = Map.take(attrs, [:user])

    build_package_template = fn ->
      build(:package, user_attr)
    end

    package =
      case attrs do
        %{package: package} ->
          fn ->
            build(
              :package,
              package
              |> Map.put_new_lazy(:package_template, build_package_template)
              |> Enum.into(user_attr)
            )
          end

        _ ->
          nil
      end

    %Job{
      type: "wedding",
      client: fn ->
        build(:client, attrs |> Map.get(:client, %{}) |> Enum.into(user_attr))
      end,
      package: package,
      shoots: fn ->
        case attrs do
          %{shoots: shoots} ->
            for shoot <- shoots, do: build(:shoot, shoot)

          _ ->
            []
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:client, :package, :shoots, :user]))
    |> evaluate_lazy_attributes()
  end
end
