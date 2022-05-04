defmodule Picsello.Factory do
  @moduledoc """
  test helpers for creating job entities
  """

  use ExMachina.Ecto, repo: Picsello.Repo
  import Money.Sigils

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
    PaymentSchedule,
    Repo,
    Shoot,
    Accounts.User,
    Questionnaire,
    Questionnaire.Answer,
    Galleries.Gallery,
    Galleries.Album,
    Galleries.Watermark,
    Galleries.Photo,
    Profiles.Profile
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

  def onboard!(%User{onboarding: nil} = user) do
    organization =
      user
      |> Repo.preload(:organization)
      |> Map.get(:organization)

    if !organization.profile do
      organization
      |> Ecto.Changeset.change(profile: build(:profile))
      |> Repo.update!()
    end

    user
    |> Ecto.Changeset.change(onboarding: build(:onboarding))
    |> Repo.update!()
  end

  def onboard!(%User{onboarding: %{completed_at: %DateTime{}}} = user), do: user

  def onboarding_factory,
    do: %Onboardings.Onboarding{
      phone: "(918) 555-1234",
      photographer_years: 1,
      switching_from_softwares: [:none],
      schedule: :part_time,
      completed_at: DateTime.utc_now(),
      state: "OK",
      intro_states:
        Enum.map(
          ~w[intro_dashboard intro_inbox intro_marketing intro_tour intro_leads_empty intro_leads_new intro_settings_profile intro_settings_packages intro_settings_pricing intro_settings_public_profile intro_settings_contacts],
          &%{id: &1, state: :completed, changed_at: DateTime.utc_now()}
        )
    }

  def profile_factory,
    do: %{
      color: Profile.colors() |> hd,
      is_enabled: true,
      job_types: ["event", "wedding", "newborn"],
      no_website: true
    }

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
      buy_all: 5000,
      print_credits: 200,
      download_count: 0,
      download_each_price: 0,
      name: "Package name",
      description: "<p>Package description</p>",
      shoot_count: 2,
      turnaround_weeks: 1,
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
    %BookingProposal{job: fn -> build(:lead, %{user: insert(:user)}) end}
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def payment_schedule_factory(attrs) do
    %PaymentSchedule{
      due_at: DateTime.utc_now(),
      price: Money.new(500),
      description: "invoice",
      job: fn -> build(:lead, %{user: insert(:user)}) end
    }
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
    %{package: %{shoot_count: shoot_count} = package, shoots: shoots} =
      Repo.preload(job, [:package, :shoots], force: true)

    insert(:proposal,
      job: job,
      accepted_at: DateTime.utc_now(),
      signed_at: DateTime.utc_now()
    )

    price = package |> Package.price() |> Money.multiply(0.5)

    insert(:payment_schedule,
      job: job,
      paid_at: DateTime.utc_now(),
      due_at: DateTime.utc_now(),
      price: price
    )

    insert(:payment_schedule,
      job: job,
      due_at: DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60),
      price: price
    )

    insert_list(shoot_count - Enum.count(shoots), :shoot, job: job)

    job |> Repo.preload(:shoots, force: true)
  end

  def lead_factory(attrs) do
    user_attr = attrs |> Map.put_new_lazy(:user, fn -> insert(:user) end) |> Map.take([:user])

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
        attrs
        |> Map.get(:client, %{})
        |> case do
          %Picsello.Client{id: id} = client when is_integer(id) -> client
          client_attrs -> build(:client, client_attrs |> Enum.into(user_attr))
        end
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

  def album_factory(attrs) do
    %Album{
      name: "Test album",
      set_password: false,
      password: nil
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def gallery_factory(attrs) do
    %Gallery{
      name: "Test Client Wedding",
      job: fn -> build(:lead) end,
      password: valid_gallery_password(),
      client_link_hash: UUID.uuid4()
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def watermark_factory(attrs) do
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
      aspect_ratio: 1.0,
      original_url: Photo.original_path("name", 333, "4444")
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def whcc_editor_export_factory(attrs) do
    unit_base_price = Map.get(attrs, :unit_base_price, ~M[1]USD)
    quantity = Map.get(attrs, :quantity, 1)

    %Picsello.WHCC.Editor.Export{
      items: [
        %Picsello.WHCC.Editor.Export.Item{quantity: quantity, unit_base_price: unit_base_price}
      ],
      order: %{},
      pricing: %{
        "totalOrderBasePrice" => Money.multiply(unit_base_price, quantity).amount / 100,
        "code" => "USD"
      }
    }
    |> merge_attributes(Map.drop(attrs, [:quantity, :unit_base_price]))
  end

  def category_factory,
    do: %Picsello.Category{
      whcc_id: sequence("whcc_id"),
      whcc_name: "shirts",
      name: "cool shirts",
      position: sequence(:category_position, & &1),
      shipping_base_charge: ~M[900]USD,
      shipping_upcharge: Decimal.new("0.09"),
      icon: "book",
      default_markup: 1.0,
      hidden: false
    }

  def product_factory do
    product_json =
      "test/support/fixtures/whcc/api/v1/products/44oa66BP8N9NtBknE.json"
      |> File.read!()
      |> Jason.decode!()

    whcc_product =
      product_json
      |> Picsello.WHCC.Product.from_map()
      |> Picsello.WHCC.Product.add_details(product_json)

    %Picsello.Product{
      whcc_id: sequence("whcc_id"),
      whcc_name: "polo",
      position: sequence(:product_position, & &1),
      attribute_categories: whcc_product.attribute_categories,
      api: whcc_product.api,
      category: fn ->
        %{category: %{id: whcc_id}} = whcc_product
        Repo.get_by(Picsello.Category, whcc_id: whcc_id) || build(:category, whcc_id: whcc_id)
      end
    }
    |> evaluate_lazy_attributes()
  end

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
      turnaround_weeks: 1,
      download_count: 10
    }

  def whcc_editor_details_factory(attrs \\ %{}) do
    %Picsello.WHCC.Editor.Details{
      editor_id: sequence("hkazbRKGjcoWwnEq3"),
      preview_url:
        "https://d3fvjqx1d7l6w5.cloudfront.net/a0e912a6-34ef-4963-b04d-5f4a969e2237.jpeg",
      product_id: fn -> insert(:product).whcc_id end,
      selections: %{
        "display_options" => "no",
        "quantity" => Map.get(attrs, :quantity, 1),
        "size" => "20x30",
        "surface" => "1_4in_acrylic_with_styrene_backing"
      }
    }
    |> merge_attributes(Map.drop(attrs, [:quantity]))
    |> evaluate_lazy_attributes()
  end

  def cart_product_factory(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :product_id, get_in(attrs, [:whcc_product, :whcc_id]))

    %Picsello.Cart.CartProduct{
      created_at: System.os_time(:millisecond),
      editor_details: build(:whcc_editor_details, Map.take(attrs, [:product_id, :quantity])),
      quantity: 1,
      round_up_to_nearest: 500,
      shipping_base_charge: %Money{amount: 900, currency: :USD},
      shipping_upcharge: Decimal.new("0.09"),
      unit_markup: %Money{amount: 35_200, currency: :USD},
      unit_price: %Money{amount: 17_600, currency: :USD},
      whcc_processing: nil,
      whcc_tracking: nil,
      whcc_product: nil
    }
    |> merge_attributes(Map.drop(attrs, [:product_id]))
  end

  def whcc_order_created_factory(attrs) do
    %Picsello.WHCC.Order.Created{
      confirmation: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
      entry: "hkazbRKGjcoWwnEq3",
      orders: fn ->
        case attrs do
          %{total: total} -> [%Picsello.WHCC.Order.Created.Order{total: total}]
          _ -> []
        end
      end
    }
    |> merge_attributes(Map.drop(attrs, [:total]))
    |> evaluate_lazy_attributes()
  end

  def order_factory,
    do:
      %Picsello.Cart.Order{gallery: fn -> build(:gallery) end}
      |> evaluate_lazy_attributes()

  def confirmed_order_factory(attrs) do
    %Picsello.Cart.Order{
      delivery_info: %Picsello.Cart.DeliveryInfo{
        address: %Picsello.Cart.DeliveryInfo.Address{
          addr1: "1234 Hogwarts Way",
          addr2: nil,
          city: "New York",
          country: "US",
          state: "NY",
          zip: "10001"
        },
        email: "hello@gmail.com",
        name: "Harry Potter"
      },
      number: 226_160,
      placed_at: ~U[2022-01-17 09:42:05Z]
    }
    |> merge_attributes(attrs)
  end

  def email_preset_factory,
    do: %Picsello.EmailPreset{
      subject_template: "Subjectively speaking",
      body_template: "this is my body",
      name: "use this email preset!",
      position: 0
    }

  def gallery_product_factory, do: %Picsello.Galleries.GalleryProduct{}

  def subscription_plan_factory,
    do: %Picsello.SubscriptionPlan{
      stripe_price_id: "price_123",
      recurring_interval: "month",
      price: 5000
    }

  def subscription_event_factory,
    do: %Picsello.SubscriptionEvent{
      stripe_subscription_id: "sub_123",
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.utc_now() |> DateTime.add(60 * 60 * 24)
    }

  def digital_factory,
    do:
      %Picsello.Cart.Digital{
        price: ~M[500]USD,
        photo: fn _ -> build(:photo) end,
        position: sequence(:position, & &1)
      }
      |> evaluate_lazy_attributes()

  def tax_schedule_factory do
    %{
      year: 2022,
      self_employment_percentage: 15.3,
      active: true,
      income_brackets: [
        %{
          fixed_cost_start: ~M[000]USD,
          fixed_cost: ~M[000]USD,
          income_min: ~M[000]USD,
          income_max: ~M[999500]USD,
          percentage: 10
        },
        %{
          fixed_cost_start: ~M[999600]USD,
          fixed_cost: ~M[100000]USD,
          income_min: ~M[999500]USD,
          income_max: ~M[000]USD,
          percentage: 24
        }
      ]
    }
  end

  def business_cost_factory do
    %{
      category: "Equipment",
      active: true,
      description:
        "Everything you use to run your photography business. Cameras, stands, lights, etc",
      line_items: [
        %{
          title: "Camera",
          description: "The core to your business",
          yearly_cost: ~M[600000]USD
        },
        %{
          title: "Light",
          description: "Light up your subjects",
          yearly_cost: ~M[50000]USD
        }
      ]
    }
  end

  def tax_schedule(%{session: _session}) do
    Picsello.PricingCalculatorTaxSchedules.changeset(
      %Picsello.PricingCalculatorTaxSchedules{},
      tax_schedule_factory()
    )
    |> Picsello.Repo.insert!()

    {:ok, %{}}
  end

  def business_costs(%{session: _session}) do
    Picsello.PricingCalculatorBusinessCosts.changeset(
      %Picsello.PricingCalculatorBusinessCosts{},
      business_cost_factory()
    )
    |> Picsello.Repo.insert!()

    {:ok, %{}}
  end
end
