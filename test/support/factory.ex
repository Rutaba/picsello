defmodule Picsello.Factory do
  @moduledoc """
  test helpers for creating job entities
  """

  use ExMachina.Ecto, repo: Picsello.Repo
  import Money.Sigils

  alias Picsello.{
    BookingProposal,
    Client,
    Repo,
    Job,
    Organization,
    OrganizationJobType,
    Package,
    Campaign,
    CampaignClient,
    ClientMessage,
    Onboardings,
    PaymentSchedule,
    Shoot,
    Accounts.User,
    Questionnaire,
    Questionnaire.Answer,
    Galleries.Gallery,
    Galleries.Album,
    Galleries.Watermark,
    Galleries.Photo,
    Profiles.Profile,
    BrandLink,
    Questionnaire,
    PackagePaymentSchedule
  }

  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.GlobalSettings.PrintProduct

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
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_embed(:onboarding, %{completed_at: DateTime.utc_now(), welcome_count: 0})
    |> Repo.update!()
  end

  def onboard!(%User{onboarding: nil} = user) do
    organization =
      user
      |> Repo.preload(organization: :organization_job_types)
      |> Map.get(:organization)

    if !organization.profile do
      organization
      |> Ecto.Changeset.change(profile: build(:profile))
      |> Ecto.Changeset.change(organization_job_types: organization_job_types())
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
          ~w[intro_dashboard_modal intro_inbox intro_marketing intro_tour intro_leads_new intro_settings_profile intro_settings_public_profile intro_settings_clients intro_jobs intro_settings_brand intro_settings_finances],
          &%{id: &1, state: :completed, changed_at: DateTime.utc_now()}
        )
    }

  def profile_factory,
    do: %{
      color: Profile.colors() |> hd,
      is_enabled: true
    }

  def organization_job_types,
    do: [
      %OrganizationJobType{job_type: "event", show_on_business?: true, show_on_profile?: true},
      %OrganizationJobType{job_type: "wedding", show_on_business?: true, show_on_profile?: true},
      %OrganizationJobType{job_type: "newborn", show_on_business?: true, show_on_profile?: true}
    ]

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
      slug: sequence(:slug, &"camera-user-group-#{&1}"),
      organization_cards: Picsello.OrganizationCard.for_new_changeset()
    }
  end

  def package_factory(attrs) do
    %Package{
      base_price: Map.get(attrs, :base_price, 1000),
      buy_all: nil,
      print_credits: 0,
      download_count: 0,
      download_each_price: 0,
      name: "Package name",
      description: "<p>Package description</p>",
      shoot_count: 2,
      turnaround_weeks: 1,
      fixed: true,
      schedule_type: "headshot",
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

  def brand_link_factory(attrs) do
    %BrandLink{
      title: "Website",
      link: "photos.example.com",
      link_id: "website",
      organization_id: fn ->
        case attrs do
          %{user: user} ->
            user
            |> Repo.preload(:organization)
            |> Map.get(:organization)
            |> Map.get(:id)

          _ ->
            build(:organization, Map.get(attrs, :organization, %{})) |> Map.get(:id)
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

  def package_payment_schedule_factory(attrs) do
    package =
      case attrs do
        %{package: package} -> package
        _ -> build(:package, attrs)
      end

    price =
      case attrs do
        %{price: price} -> price
        _ -> Money.new(100)
      end

    %PackagePaymentSchedule{
      price: price,
      interval: true,
      due_interval: "To Book",
      description: "#{price} to To Book",
      schedule_date: "3022-01-01 00:00:00",
      package: package
    }
    |> merge_attributes(Map.drop(attrs, [:user]))
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

    add_contract(package)

    job |> Repo.preload(:shoots, force: true)
  end

  def add_contract(%Package{} = package) do
    default_contract = Picsello.Contracts.default_contract(package)
    insert(:contract, package_id: package.id, contract_template_id: default_contract.id)
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

  def proofing_album_factory(attrs) do
    %Album{
      name: "Test proof album",
      is_proofing: true,
      set_password: true,
      password: Gallery.generate_password(),
      client_link_hash: UUID.uuid4()
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def gallery_factory(attrs) do
    {lead_attrs, attrs} = Map.split(attrs, [:package])

    %Gallery{
      name: "Test Client Wedding",
      job: fn -> insert(:lead, lead_attrs) |> promote_to_job() end,
      password: valid_gallery_password(),
      client_link_hash: UUID.uuid4(),
      use_global: %{watermark: false, expiration: false, digital: false, products: false}
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def global_gallery_settings_factory(attrs) do
    %GSGallery{}
    |> GSGallery.expiration_changeset(%{})
    |> Ecto.Changeset.apply_changes()
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def watermark_factory(attrs) do
    %Watermark{
      type: :text,
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
      original_url: Photo.original_path("name", 333, "4444"),
      width: 300,
      height: 300,
      active: true
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def whcc_editor_export_factory(attrs) do
    {unit_base_price, attrs} = Map.pop(attrs, :unit_base_price, ~M[1]USD)
    {quantity, attrs} = Map.pop(attrs, :quantity, 1)

    {order_sequence_number, attrs} =
      Map.pop_lazy(attrs, :order_sequence_number, fn -> sequence(:order_sequence_number, & &1) end)

    %Picsello.WHCC.Editor.Export{
      items: [
        %Picsello.WHCC.Editor.Export.Item{
          quantity: quantity,
          unit_base_price: unit_base_price,
          order_sequence_number: order_sequence_number
        }
      ],
      order: %{},
      pricing: %{
        "totalOrderBasePrice" => Money.multiply(unit_base_price, quantity).amount / 100,
        "totalOrderMarkedUpPrice" => 5.5,
        "code" => "USD"
      }
    }
    |> merge_attributes(attrs)
  end

  def category_factory(attr \\ %{}),
    do:
      %Picsello.Category{
        whcc_id: sequence("whcc_id"),
        whcc_name: "shirts",
        name: "cool shirts",
        position: sequence(:category_position, & &1),
        shipping_base_charge: ~M[900]USD,
        shipping_upcharge: Decimal.new("0.09"),
        icon: "book",
        default_markup: 1.0,
        hidden: false,
        coming_soon: false
      }
      |> merge_attributes(attr)

  def product_factory do
    product_json =
      "test/support/fixtures/whcc/api/v1/products/44oa66BP8N9NtBknE.json"
      |> File.read!()
      |> Jason.decode!()

    whcc_product =
      product_json
      |> update_in(["category", "id"], &"#{&1}-#{sequence("whcc_id")}")
      |> Picsello.WHCC.Product.from_map()
      |> Picsello.WHCC.Product.add_details(product_json)

    %Picsello.Product{
      whcc_id: sequence("whcc_id"),
      whcc_name: "polo",
      position: sequence(:product_position, & &1),
      attribute_categories: whcc_product.attribute_categories,
      api: whcc_product.api,
      shipping_upcharge: %{"default" => 20},
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
      preview_url: image_url(),
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
    %Picsello.Cart.Product{
      editor_id: sequence(:whcc_editor_id, &"whcc-editor-id#{&1}"),
      quantity: 1,
      shipping_base_charge: %Money{amount: 3_800, currency: :USD},
      shipping_upcharge: Decimal.new("0.09"),
      unit_markup: %Money{amount: 35_200, currency: :USD},
      unit_price: %Money{amount: 17_600, currency: :USD},
      whcc_product: fn -> insert(:product) end,
      preview_url: image_url(),
      total_markuped_price: %Money{amount: 50_200, currency: :USD},
      selections: %{
        "display_options" => "no",
        "quantity" => Map.get(attrs, :quantity, 1),
        "size" => "20x30",
        "surface" => "1_4in_acrylic_with_styrene_backing"
      },
      volume_discount: ~M[0]USD,
      print_credit_discount: ~M[0]USD,
      price: ~M[55500]USD
    }
    |> evaluate_lazy_attributes()
    |> merge_attributes(Map.drop(attrs, [:account_id]))
  end

  def whcc_order_created_order_factory do
    %Picsello.WHCC.Order.Created.Order{
      total: ~M[100]USD,
      sequence_number: sequence(:sequence_number, & &1)
    }
  end

  def whcc_order_created_factory(attrs) do
    {total, attrs} = Map.pop(attrs, :total)

    {sequence_number, attrs} =
      Map.pop_lazy(attrs, :sequence_number, fn -> sequence(:sequence_number, & &1) end)

    %Picsello.WHCC.Order.Created{
      confirmation_id: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
      entry_id: "hkazbRKGjcoWwnEq3",
      orders: fn ->
        case total do
          nil ->
            []

          total ->
            build_list(1, :whcc_order_created_order,
              total: total,
              sequence_number: sequence_number
            )
        end
      end
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def order_factory,
    do:
      %Picsello.Cart.Order{gallery: fn -> build(:gallery) end}
      |> evaluate_lazy_attributes()

  def email_preset_factory(attrs),
    do:
      %Picsello.EmailPresets.EmailPreset{
        subject_template: "Subjectively speaking",
        body_template: "this is my body",
        name: "use this email preset!",
        type: :job,
        position: 0
      }
      |> merge_attributes(attrs)

  def global_gallery_product_factory, do: %Picsello.GlobalSettings.GalleryProduct{}
  def gallery_product_factory, do: %Picsello.Galleries.GalleryProduct{}

  def global_gallery_print_product_factory,
    do:
      %PrintProduct{
        sizes: [
          %{
            size: "4x4",
            type: "smooth_matte",
            final_cost: 50_000
          },
          %{
            size: "5x8",
            type: "lusture",
            final_cost: 80_000
          }
        ]
      }
      |> evaluate_lazy_attributes()

  def subscription_promotion_codes_factory(attrs \\ %{}) do
    %Picsello.SubscriptionPromotionCode{
      code: "10OFF",
      stripe_promotion_code_id: "1234asd",
      percent_off: 10.0
    }
    |> merge_attributes(attrs)
  end

  def subscription_plan_factory,
    do: %Picsello.SubscriptionPlan{
      stripe_price_id: "price_123",
      recurring_interval: "month",
      active: true,
      price: 2000
    }

  def insert_subscription_plans!() do
    [
      insert(:subscription_plan),
      insert(:subscription_plan,
        recurring_interval: "year",
        stripe_price_id: "price_987",
        price: 50_000,
        active: true
      )
    ]
  end

  def subscription_event_factory,
    do: %Picsello.SubscriptionEvent{
      stripe_subscription_id: "sub_123",
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.utc_now() |> DateTime.add(60 * 60 * 24)
    }

  def subscription_metadata_factory(attrs),
    do:
      %Picsello.SubscriptionPlansMetadata{
        code: "123456",
        trial_length: 90,
        active: false,
        signup_title: "Get started with your free 90-day free trial today",
        signup_description:
          "Start your 90-day free trial today and find out how simple it is to manage, market, and monetize your photography business with Picsello. It’s never been easier to grow doing what you love into a successful business.",
        onboarding_title: "Start your 90-day free trial",
        onboarding_description:
          "Your 90-day free trial lets you explore and use all of our amazing features.",
        success_title: "Your 90-day free trial has started!"
      }
      |> merge_attributes(attrs)

  def insert_subscription_metadata_factory!(attrs) do
    insert(subscription_metadata_factory(attrs))
  end

  def generate_random_code(), do: Enum.random(100_000..999_999) |> to_string

  def digital_factory,
    do:
      %Picsello.Cart.Digital{
        price: ~M[500]USD,
        photo: fn _ -> build(:photo) end
      }
      |> evaluate_lazy_attributes()

  def contract_template_factory(attrs) do
    %Picsello.Contract{
      name: "My custom contract",
      job_type: "wedding",
      content: "the greatest contract",
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

  def contract_factory(attrs) do
    %Picsello.Contract{
      name: "My job custom contract",
      content: "the greatest job contract"
    }
    |> merge_attributes(attrs)
  end

  def tax_schedule_factory do
    %{
      year: 2023,
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

  def intent_factory do
    %Picsello.Intents.Intent{
      amount: ~M[100]USD,
      amount_capturable: ~M[0]USD,
      amount_received: ~M[0]USD,
      application_fee_amount: ~M[0]USD,
      order: fn -> build(:order) end,
      status: :requires_payment_method,
      stripe_payment_intent_id: sequence(:payment_intent, &"payment-intent-#{&1}"),
      stripe_session_id: sequence(:session, &"session-#{&1}")
    }
    |> evaluate_lazy_attributes()
  end

  def invoice_factory do
    %Picsello.Invoices.Invoice{
      amount_due: ~M[0]USD,
      amount_paid: ~M[0]USD,
      amount_remaining: ~M[0]USD,
      order: fn -> build(:order) end,
      description: "an invoice",
      status: :draft,
      stripe_id: sequence(:invoice, &"invoice-#{&1}")
    }
    |> evaluate_lazy_attributes()
  end

  def stripe_payment_intent_factory() do
    %Stripe.PaymentIntent{
      amount: 0,
      amount_received: 0,
      amount_capturable: 0,
      application_fee_amount: 0,
      status: "requires_payment_method",
      id: sequence(:payment_intent_stripe_id, &"payment-intent-stripe-id-#{&1}")
    }
  end

  def stripe_session_factory do
    %Stripe.Session{
      id: sequence(:session, &"session-#{&1}"),
      payment_intent: build(:stripe_payment_intent)
    }
  end

  def stripe_invoice_factory() do
    %Stripe.Invoice{
      amount_due: ~M[0]USD,
      amount_paid: ~M[0]USD,
      amount_remaining: ~M[0]USD,
      description: "invoice description",
      status: "draft",
      id: sequence(:invoice_stripe_id, &"invoice-stripe-id-#{&1}")
    }
  end

  def booking_event_factory() do
    %Picsello.BookingEvent{
      name: "My event",
      location: "on_location",
      address: "320 1st St N, Jax Beach, FL",
      duration_minutes: 45,
      buffer_minutes: 15,
      dates: [
        %{
          date: ~D[2050-12-10],
          time_blocks: [
            %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
            %{start_time: ~T[15:00:00], end_time: ~T[17:00:00]}
          ]
        }
      ],
      thumbnail_url: PicselloWeb.Endpoint.static_url() <> "/images/phoenix.png",
      description: "<p>My custom description</p>"
    }
  end

  def image_url(),
    do:
      PicselloWeb.Endpoint.struct_url()
      |> Map.put(:path, PicselloWeb.Endpoint.static_path("/images/phoenix.png"))
      |> URI.to_string()

  @concise_name "proofing-album-order"
  def proofs_organization_card_factory,
    do: %Picsello.OrganizationCard{
      status: :active,
      card_id: Repo.get_by(Picsello.Card, concise_name: @concise_name).id
    }
end
