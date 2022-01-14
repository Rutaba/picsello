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
    Campaign,
    CampaignClient,
    ClientMessage,
    Onboardings,
    Repo,
    Shoot,
    Accounts.User,
    Questionnaire,
    Questionnaire.Answer,
    Galleries.Gallery,
    Galleries.Watermark,
    Galleries.Photo
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

  def onboard_show_intro!(%User{} = user) do
    user
    |> User.complete_onboarding_changeset()
    |> Repo.update!()
  end

  def onboard!(%User{} = user) do
    user
    |> User.complete_onboarding_changeset()
    |> Repo.update!()
    |> Onboardings.save_intro_state("intro_dashboard", "completed")
    |> Onboardings.save_intro_state("intro_inbox", "completed")
    |> Onboardings.save_intro_state("intro_marketing", "completed")
    |> Onboardings.save_intro_state("intro_tour", "completed")
    |> Onboardings.save_intro_state("intro_leads_empty", "completed")
    |> Onboardings.save_intro_state("intro_leads_new", "completed")
    |> Onboardings.save_intro_state("intro_settings", "completed")
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
    %Organization{
      name: "Camera User Group",
      slug: sequence(:slug, &"camera-user-group-#{&1}")
    }
  end

  def package_factory(attrs) do
    %Package{
      base_price: 1000,
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

  def package_template_factory(attrs) do
    build(:package, attrs)
    |> merge_attributes(attrs |> Map.drop([:user]) |> Enum.into(%{job_type: "wedding"}))
  end

  def campaign_factory(attrs) do
    %Campaign{
      subject: "here is a subject",
      body_text: "lets take some pictures!",
      body_html: "lets take <i>some</i> <b>pictures!</b>",
      segment_type: "all",
      organization: fn ->
        case attrs do
          %{user: user} -> user |> Repo.preload(:organization) |> Map.get(:organization)
          _ -> build(:organization, Map.get(attrs, :organization, %{}))
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:user, :organization]))
    |> evaluate_lazy_attributes()
  end

  def campaign_client_factory(attrs) do
    %CampaignClient{}
    |> merge_attributes(attrs)
  end

  def client_factory(attrs) do
    %Client{
      email: sequence(:email, &"client-#{&1}@example.com"),
      name: "Mary Jane",
      phone: "(904) 555-5555",
      organization: fn ->
        case attrs do
          %{user: user} -> user |> Repo.preload(:organization) |> Map.get(:organization)
          _ -> build(:organization, Map.get(attrs, :organization, %{}))
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:user, :organization]))
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
      body_html: "lets take <i>some</i> <b>pictures!</b>",
      read_at: DateTime.utc_now() |> DateTime.truncate(:second),
      outbound: true
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
        %{package: %Package{} = package} ->
          package

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

  def gallery_factory(attrs) do
    %Gallery{
      name: "Test Client Weding",
      job: fn -> build(:lead) end,
      password: valid_gallery_password(),
      client_link_hash: UUID.uuid4()
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def text_watermark_factory(attrs) do
    %Watermark{
      type: "text",
      text: "007Agency:)"
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def photo_factory(attrs) do
    %Photo{
      gallery: fn -> build(:gallery) end,
      name: "name.jpg",
      position: 1.0,
      original_url: Photo.original_path("name", 333, "4444")
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def category_factory,
    do: %Picsello.Category{
      whcc_id: sequence("whcc_id"),
      whcc_name: "shirts",
      name: "cool shirts",
      position: sequence(:category_position, & &1),
      icon: "book",
      default_markup: 2.0
    }

  def product_factory,
    do:
      %Picsello.Product{
        whcc_id: sequence("whcc_id"),
        whcc_name: "polo",
        position: sequence(:product_position, & &1),
        category: fn -> build(:category) end
      }
      |> evaluate_lazy_attributes()

  def design_factory,
    do:
      %Picsello.Design{
        whcc_id: sequence("whcc_id"),
        whcc_name: "birthday",
        position: 0,
        product: fn -> build(:product) end
      }
      |> evaluate_lazy_attributes()

  def markup_factory,
    do: %Picsello.Markup{
      organization: fn -> build(:organization) end,
      product: fn -> build(:product) end,
      whcc_attribute_category_id: "surface",
      whcc_attribute_id: "matte",
      whcc_variation_id: "4x4",
      value: 100.0
    }

  def valid_gallery_password(), do: "123456"

  def cost_of_living_adjustment_factory(),
    do: %Picsello.Packages.CostOfLivingAdjustment{state: "OK", multiplier: 1.0}

  def package_tier_factory(),
    do: %Picsello.Packages.Tier{name: "mid", position: 1}

  def package_base_price_factory(),
    do: %Picsello.Packages.BasePrice{
      tier: "mid",
      job_type: "event",
      full_time: true,
      min_years_experience: 1,
      base_price: 100,
      shoot_count: 2,
      download_count: 10
    }

  def cart_product_factory(%{product_id: product_id}) do
    %Picsello.Cart.CartProduct{
      base_price: %Money{amount: 17_600, currency: :USD},
      editor_details: %Picsello.WHCC.Editor.Details{
        editor_id: sequence("hkazbRKGjcoWwnEq3"),
        preview_url:
          "https://d3fvjqx1d7l6w5.cloudfront.net/a0e912a6-34ef-4963-b04d-5f4a969e2237.jpeg",
        product_id: product_id,
        selections: %{
          "display_options" => "no",
          "quantity" => 1,
          "size" => "20x30",
          "surface" => "1_4in_acrylic_with_styrene_backing"
        }
      },
      price: %Money{amount: 35_200, currency: :USD},
      whcc_confirmation: nil,
      whcc_order: nil,
      whcc_processing: nil,
      whcc_tracking: nil
    }
  end

  def whcc_order_created_factory do
    %Picsello.WHCC.Order.Created{
      confirmation: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
      entry: "hkazbRKGjcoWwnEq3",
      products: [
        %{
          "Price" => "176.00",
          "ProductDescription" => "Acrylic Print 1/4\" with Styrene Backing 20x30",
          "Quantity" => 1
        },
        %{
          "Price" => "8.80",
          "ProductDescription" => "Peak Season Surcharge",
          "Quantity" => 1
        },
        %{
          "Price" => "65.60",
          "ProductDescription" => "Fulfillment Shipping WD - NDS or 2 day",
          "Quantity" => 1
        }
      ],
      total: "250.40"
    }
  end

  def ordered_cart_product_factory(%{product_id: product_id}) do
    %Picsello.Cart.CartProduct{
      base_price: %Money{amount: 17_600, currency: :USD},
      editor_details: %Picsello.WHCC.Editor.Details{
        editor_id: "hkazbRKGjcoWwnEq3",
        preview_url:
          "https://d3fvjqx1d7l6w5.cloudfront.net/a0e912a6-34ef-4963-b04d-5f4a969e2237.jpeg",
        product_id: product_id,
        selections: %{
          "display_options" => "no",
          "quantity" => 1,
          "size" => "20x30",
          "surface" => "1_4in_acrylic_with_styrene_backing"
        }
      },
      price: %Money{amount: 35_200, currency: :USD},
      whcc_confirmation: nil,
      whcc_order: %Picsello.WHCC.Order.Created{
        confirmation: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
        entry: "hkazbRKGjcoWwnEq3",
        products: [
          %{
            "Price" => "176.00",
            "ProductDescription" => "Acrylic Print 1/4\" with Styrene Backing 20x30",
            "Quantity" => 1
          },
          %{
            "Price" => "8.80",
            "ProductDescription" => "Peak Season Surcharge",
            "Quantity" => 1
          },
          %{
            "Price" => "65.60",
            "ProductDescription" => "Fulfillment Shipping WD - NDS or 2 day",
            "Quantity" => 1
          }
        ],
        total: "250.40"
      },
      whcc_processing: nil,
      whcc_tracking: nil
    }
  end
end
