defmodule Picsello.Repo.Migrations.AddCardsTable do
  use Ecto.Migration

  def up do
    create table(:cards) do
      add(:concise_name, :string, null: false)
      add(:title, :string, null: false)
      add(:body, :string)
      add(:index, :integer)
      add(:icon, :string)
      add(:color, :string)
      add(:class, :string)
      add(:buttons, :jsonb)

      timestamps()
    end

    flush()

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    [
      %{
        concise_name: "proofing-album-order",
        title: "A client selected their proofs!",
        body: "Your client, {{name}}, has sent their selection from their proofing album!",
        icon: "proof_notifier",
        index: 1,
        buttons: [
          %{
            label: "Go to Proof list",
            class: "btn-secondary",
            link: ""
          },
          %{
            label: "Download .CSV",
            class: "btn-secondary",
            link: ""
          }
        ],
        color: "blue-planning-300",
        class: "intro-resources"
      },
      %{
        concise_name: "send-confirmation-email",
        title: "Confirm your email",
        body: "Check your email to confirm your account before you can start anything.",
        icon: "envelope",
        index: 2,
        buttons: [
          %{
            label: "Resend email",
            class: "btn-primary",
            action: "send-confirmation-email"
          }
        ],
        color: "red-sales-300",
        class: "intro-confirmation border-red-sales-300"
      },
      %{
        concise_name: "open-user-settings",
        title: "Subscription ending soon",
        body:
          "You have {{days_left}} left before your subscription ends. You will lose access on {{subscription_end_at}}. Your data will not be deleted and you can resubscribe at any time",
        icon: "clock-filled",
        index: 3,
        buttons: [
          %{
            label: "Go to acccount settings",
            class: "btn-secondary",
            action: "open-user-settings"
          }
        ],
        color: "red-sales-300",
        class: "intro-confirmation border-red-sales-300"
      },
      %{
        concise_name: "getting-started-picsello",
        title: "Getting started with Picsello guide",
        body: "Check out our guide on how best to start running your business with Picsello.",
        icon: "question-mark",
        index: 4,
        buttons: [
          %{
            label: "Open guide",
            class: "btn-secondary",
            external_link:
              "https://support.picsello.com/article/117-getting-started-with-picsello-guide"
          }
        ],
        color: "blue-planning-300",
        class: "intro-help-scout"
      },
      %{
        concise_name: "set-up-stripe",
        title: "Set up Stripe",
        body: "We use Stripe to make payment collection as seamless as possible for you.",
        icon: "money-bags",
        index: 5,
        buttons: [
          %{
            label: "Setup your Stripe Account",
            class: "btn-secondary",
            action: "set-up-stripe"
          }
        ],
        color: "blue-planning-300",
        class: "intro-stripe"
      },
      %{
        concise_name: "client-booking",
        title: "Client booking is here!",
        body: "Your clients will go from looking to direct booking in under 10 minutes.",
        icon: "calendar",
        index: 6,
        buttons: [
          %{
            label: "Check it out",
            class: "btn-secondary",
            link: "/booking-events"
          }
        ],
        color: "blue-planning-300",
        class: ""
      },
      %{
        concise_name: "open-billing-portal",
        title: "Balance(s) Due",
        body:
          "Oh no! We don't have an updated credit card on file. Please resolve in the Billing Portal to ensure continued service and product delivery for clients.",
        icon: "money-bags",
        index: 7,
        buttons: [
          %{
            label: "Open Billing Portal",
            class: "btn-primary",
            action: "open-billing-portal"
          }
        ],
        color: "red-sales-300",
        class: "border-red-sales-300"
      },
      %{
        concise_name: "missing-payment-method",
        title: "Missing Payment Method",
        body:
          "Oh no! You won't be able to sell physical gallery products until we have a payment method. If you're having trouble, please contact support.",
        icon: "money-bags",
        index: 8,
        buttons: [
          %{
            label: "Open Billing Portal",
            class: "btn-primary",
            action: "open-billing-portal"
          }
        ],
        color: "red-sales-300",
        class: "border-red-sales-300"
      },
      %{
        concise_name: "gallery-links",
        title: "Preview the gallery experience",
        body: "We’ve created a video overview of how galleries work to help you get started.",
        icon: "add-photos",
        index: 9,
        buttons: [
          %{
            label: "Watch video",
            class: "btn-secondary",
            external_link: "https://www.youtube.com/watch?v=uEY3eS9cDIk"
          }
        ],
        color: "blue-planning-300",
        class: "intro-resources"
      },
      %{
        concise_name: "create-lead",
        title: "Create your first lead",
        body: "Leads are the first step to getting started with Picsello.",
        icon: "three-people",
        index: 10,
        buttons: [
          %{
            label: "Create your first lead",
            class: "btn-secondary",
            action: "create-lead"
          }
        ],
        color: "blue-planning-300",
        class: "intro-first-lead"
      },
      %{
        concise_name: "helpful-resources",
        title: "Helpful resources",
        body: "Stuck? We have a variety of resources to help you out.",
        icon: "question-mark",
        index: 11,
        buttons: [
          %{
            label: "See available resources",
            class: "btn-secondary",
            external_link: "https://support.picsello.com/"
          }
        ],
        color: "blue-planning-300",
        class: "intro-resources"
      }
    ]
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
    |> then(&Picsello.Repo.insert_all("cards", &1))
  end

  def down do
    drop(table(:cards))
  end
end
