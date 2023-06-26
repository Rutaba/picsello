defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationPipelines do
  use Ecto.Migration
  alias Picsello.Repo

  alias Picsello.EmailAutomation.{
    EmailAutomationCategory,
    EmailAutomationSubCategory
  }

  @table "email_automation_pipelines"
  def up do
    create table(@table) do
      add(:name, :string, null: false)
      add(:state, :string, null: false)
      add(:description, :text, null: false)

      add(
        :email_automation_sub_category_id,
        references(:email_automation_sub_categories, on_delete: :nothing)
      )

      add(
        :email_automation_category_id,
        references(:email_automation_categories, on_delete: :nothing)
      )

      timestamps()
    end

    create(unique_index(@table, [:name, :state]))

    flush()
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
        name: "Proposal Sent/Initiated",
        state: "booking_proposal_sent",
        description: "Runs after finishing and sending the proposal",
        email_automation_sub_category_id: automation_proposal.id,
        email_automation_category_id: email_automation_lead.id
      },
      # jobs
      %{
        name: "Client Pays Retainer",
        state: "pays_retainer",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_response.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Client Books a Booking Event",
        state: "booking_event",
        description: "Runs after finishing and sending the proposal",
        email_automation_sub_category_id: automation_response.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Day Before Shoot",
        state: "before_shoot",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_prep.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Balance Due",
        state: "balance_due",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Paid in Full",
        state: "paid_full",
        description: "Starts when client completes a booking event",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Offline Payment Selected",
        state: "offline_payment",
        description: "Starts when client completes a booking event",
        email_automation_sub_category_id: automation_reminder.id,
        email_automation_category_id: email_automation_job.id
      },
      %{
        name: "Thank You",
        state: "shoot_thanks",
        description: "Starts when client pays their first payment or retainer",
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
        state: "gallery_send_link",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Cart Abandoned",
        state: "cart_abandoned",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Gallery Expiring Soon",
        state: "gallery_expiration_soon",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Gallery Password Changed",
        state: "gallery_password_changed",
        description: "Runs after a contact/lead form submission",
        email_automation_sub_category_id: automation_notification.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Confirmation (Physical Products Only)",
        state: "order_confirmation_physical",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Confirmation (Digital Products Only)",
        state: "order_confirmation_digital",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Confirmation (Physical/Digital Products)",
        state: "order_confirmation_digital_physical",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Digitals Ready For Download",
        state: "digitals_ready_download",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_confirmation.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Has Shipped",
        state: "order_shipped",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Is Delayed",
        state: "order_delayed",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      },
      %{
        name: "Order Has Arrived",
        state: "order_arrived",
        description: "Starts when client pays their first payment or retainer",
        email_automation_sub_category_id: automation_status.id,
        email_automation_category_id: email_automation_gallery.id
      }
    ]
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
    |> then(&Picsello.Repo.insert_all(@table, &1))
  end

  def down do
    drop(table(@table))
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
end
