defmodule Mix.Tasks.ImportEmailAutomationPipelines do
  @moduledoc false

  use Mix.Task

  import Ecto.Query
  alias Picsello.Repo
  alias Picsello.EmailAutomation.{
    EmailAutomationCategory,
    EmailAutomationSubCategory,
    EmailAutomationPipeline
  }


  @shortdoc "import email automation pipelines"
  def run(_) do
    load_app()

    insert_email_pipelines()
  end

  def insert_email_pipelines() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    categories = from(sc in EmailAutomationCategory) |> Repo.all()
    sub_categories = from(sc in EmailAutomationSubCategory) |> Repo.all()
    
    {:ok, email_automation_lead} = maybe_insert_email_automation(categories, "Leads", "lead")
    {:ok, email_automation_job} = maybe_insert_email_automation(categories, "Jobs", "job")
    {:ok, email_automation_gallery} = maybe_insert_email_automation(categories, "Galleries", "gallery")

    {:ok, automation_inquiry} =
    maybe_insert_email_automation_slug(sub_categories, "Inquiry emails", "inquiry_emails")

    {:ok, automation_proposal} =
    maybe_insert_email_automation_slug(sub_categories, "Booking proposal", "booking_proposal")

    {:ok, automation_response} =
    maybe_insert_email_automation_slug(sub_categories, "Booking response emails", "booking_response_emails")

    {:ok, automation_prep} =
    maybe_insert_email_automation_slug(sub_categories, "Shoot prep emails", "shoot_prep_emails")

    {:ok, automation_reminder} =
    maybe_insert_email_automation_slug(sub_categories, "Payment reminder emails", "payment_reminder_emails")

    {:ok, automation_post} =
    maybe_insert_email_automation_slug(sub_categories, "Post shoot emails", "post_shoot_emails")

    {:ok, automation_notification} =
    maybe_insert_email_automation_slug(
      sub_categories,
      "Gallery notification emails",
      "gallery_notification_emails"
    )

    {:ok, automation_confirmation} =
    maybe_insert_email_automation_slug(sub_categories, "Order Confirmation emails", "order_confirmation_emails")

    {:ok, automation_status} =
    maybe_insert_email_automation_slug(sub_categories, "Order status emails", "order_status_emails")
    
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
        name: "Client Pays Retainer (Offline)",
        state: "pays_retainer_offline",
        description:
          "Runs after client clicks they will pay you offline (if you have this enabled)",
        email_automation_sub_category_id: automation_reminder.id,
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
    |> Enum.each(fn attrs ->      
      attrs = Map.merge(attrs, %{inserted_at: now, updated_at: now})
      pipeline = from(ep in EmailAutomationPipeline, where: ep.state == ^attrs.state) |> Repo.one()
      
      if pipeline do
        pipeline |> EmailAutomationPipeline.changeset(attrs) |> Repo.update!()
      else
        attrs |> EmailAutomationPipeline.changeset() |> Repo.insert!()
      end
    end)
  end

  defp maybe_insert_email_automation(categories, name, type) do
    category = Enum.filter(categories, & &1.type == String.to_atom(type)) |> List.first()
  
    if category do
      category
      |> EmailAutomationCategory.changeset(%{name: name})
      |> Repo.update()
  
    else
      %EmailAutomationCategory{}
      |> EmailAutomationCategory.changeset(%{
        name: name,
        type: type
      })
      |> Repo.insert()
    end
  end

  defp maybe_insert_email_automation_slug(sub_categories, name, slug) do
    sub_category = Enum.filter(sub_categories, & &1.slug == slug) |> List.first()

    if sub_category do
      sub_category
      |> EmailAutomationSubCategory.changeset(%{name: name})
      |> Repo.update()
    else
      %EmailAutomationSubCategory{}
      |> EmailAutomationSubCategory.changeset(%{
        name: name,
        slug: slug
      })
      |> Repo.insert()
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
