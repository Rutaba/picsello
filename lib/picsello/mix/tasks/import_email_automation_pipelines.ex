defmodule Mix.Tasks.ImportEmailAutomationPipelines do
  @moduledoc false

  use Mix.Task

  import Ecto.Query
  alias Picsello.Repo
  alias Picsello.EmailAutomation.{
    EmailAutomationCategory,
    EmailAutomationSubCategory
  }


  @shortdoc "import email automation pipelines"
  def run(_) do
    load_app()

    insert_email_pipelines()
  end

  def insert_email_pipelines() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {:ok, email_automation_lead} = insert_email_automation("Leads", "lead", now)
    {:ok, email_automation_job} = insert_email_automation("Jobs", "job", now)
    {:ok, email_automation_gallery} = insert_email_automation("Galleries", "gallery", now)

    {:ok, automation_inquiry} =
      insert_email_automation_slug("Inquiry emails", "inquiry_emails", now)

    {:ok, automation_proposal} =
      insert_email_automation_slug("Booking proposal", "booking_proposal", now)

    {:ok, automation_response} =
      insert_email_automation_slug("Booking response emails", "booking_response_emails", now)

    {:ok, automation_prep} =
      insert_email_automation_slug("Shoot prep emails", "shoot_prep_emails", now)

    {:ok, automation_reminder} =
      insert_email_automation_slug("Payment reminder emails", "payment_reminder_emails", now)

    {:ok, automation_post} =
      insert_email_automation_slug("Post shoot emails", "post_shoot_emails", now)

    {:ok, automation_notification} =
      insert_email_automation_slug(
        "Gallery notification emails",
        "gallery_notification_emails",
        now
      )

    {:ok, automation_confirmation} =
      insert_email_automation_slug("Order Confirmation emails", "order_confirmation_emails", now)

    {:ok, automation_status} =
      insert_email_automation_slug("Order status emails", "order_status_emails", now)
    
    [
      # leads
      %{
        name: "Client contacts you",
        state: "client_contact",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_inquiry.id,
        email_automation_category_id: email_automation_lead.id
      },
      %{
        name: "Thank you for contacting me",
        state: "manual_thank_you_lead",
        description: "Manually triggered automation",
        email_automation_sub_category_id: automation_inquiry.id,
        email_automation_category_id: email_automation_lead.id
      },
      %{
        name: "Proposal Sent/Initiated",
        state: "manual_booking_proposal_sent",
        description: "Manually triggered automation",
        email_automation_sub_category_id: automation_proposal.id,
        email_automation_category_id: email_automation_lead.id
      },
      # jobs
      %{
        name: "Client Pays Retainer",
        state: "pays_retainer",
        description: "Runs after client has paid their retainer online",
        email_automation_sub_category_id: automation_response.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Thank You for Booking",
        state: "booking_event",
        description: "Sent when the questionnaire, contract is signed and retainer is paid",
        email_automation_sub_category_id: automation_response.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Before the Shoot",
        state: "before_shoot",
        description: "Starts a week before the shoot and sends another day before the shoot",
        email_automation_sub_category_id: automation_prep.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Balance Due",
        state: "balance_due",
        description: "Triggered when a payment is due within a payment schedule",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Balance Due (Offline)",
        state: "offline_payment",
        description: "Triggered when a payment is due within a payment schedule that is offline",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      # %{
      #   name: "Client Pays Retainer (Offline)",
      #   state: "pays_retainer_offline",
      #   description:
      #     "Runs after client clicks they will pay you offline (if you have this enabled)",
      #   email_automation_sub_category_id: automation_reminder.id,
      #   email_automation_category_id: email_automation_job.id
      # },
      %{
        name: "Paid in Full (Offline)",
        state: "paid_offline_full",
        description: "Triggered when a payment schedule is completed from offline payments",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Paid in Full",
        state: "paid_full",
        description: "Triggered when a payment schedule is completed",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Thank You",
        state: "shoot_thanks",
        description:
          "Triggered after a shoot with emails 1 day & 1–9 months later to encourage reviews/bookings",
        email_automation_sub_category_id: automation_post.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Post Shoot Follow Up",
        state: "post_shoot",
        description: "Starts when client completes a booking event",
        email_automation_sub_category_id: automation_post.id,
        email_automation_category_id: email_automation_job.id
      },
      # gallery
      %{
        name: "Send Gallery Link",
        state: "manual_gallery_send_link",
        description: "Manually triggered automation",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Cart Abandoned",
        state: "cart_abandoned",
        description: "This will trigger when your client leaves product in their cart",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Gallery Expiring Soon",
        state: "gallery_expiration_soon",
        description: "This will trigger when a gallery is close to expiring",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Gallery Password Changed",
        state: "gallery_password_changed",
        description: "This will trigger when a gallery password has changed",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Send Proofing Gallery For Selection",
        state: "manual_send_proofing_gallery",
        description: "Manually triggered automation",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Send Proofing Gallery Finals",
        state: "manual_send_proofing_gallery_finals",
        description: "Manually triggered automation",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Received (Physical Products Only)",
        state: "order_confirmation_physical",
        description: "This will trigger when an order has been completed",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Received (Digital Products Only)",
        state: "order_confirmation_digital",
        description: "This will trigger when an order has been completed",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Received (Physical/Digital Products)",
        state: "order_confirmation_digital_physical",
        description: "This will trigger when an order has been completed",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Digitals Ready For Download",
        state: "digitals_ready_download",
        description: "This will trigger when digitals are packed and ready for download",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Has Shipped",
        state: "order_shipped",
        description: "This will trigger when digitals are packed and ready for download",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Is Delayed",
        state: "order_delayed",
        description: "This will trigger when an order is delayed",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Has Arrived",
        state: "order_arrived",
        description: "This will trigger when an order has arrived",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      }
    ]
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
    |> then(&Picsello.Repo.insert_all("email_automation_pipelines", &1))
  end

  defp insert_email_automation(name, type, now) do
    %EmailAutomationCategory{}
    |> EmailAutomationCategory.changeset(%{
      name: name,
      type: type,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert()
  end

  defp insert_email_automation_slug(name, slug, now) do
    %EmailAutomationSubCategory{}
    |> EmailAutomationSubCategory.changeset(%{
      name: name,
      slug: slug,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert()
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
