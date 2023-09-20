defmodule Mix.Tasks.ImportEmailPresets do
  @moduledoc false

  use Mix.Task
  require Logger
  import Ecto.Query

  alias Picsello.{
    Accounts.User,
    Repo,
    EmailPresets.EmailPreset,
    EmailAutomation.EmailAutomationPipeline
  }

  @shortdoc "import email presets"
  def run(_) do
    load_app()

    insert_emails()
  end

  def insert_emails() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    pipelines = from(p in EmailAutomationPipeline) |> Repo.all()

    organizations =
      from(u in User,
        select: %{id: u.organization_id},
        where:
          u.email in [
            "rhinop+picsello@gmail.com",
            "ops+demo@picsello.com",
            "aatanasio.dempsey@gmail.com",
            "kyle+22@picsello.com",
            "xanadupod@workwithloop.com",
            "kyle+marketing@picsello.com",
            "kyle+jane@picsello.com",
            "gallerytest@gallerytest.com"
          ]
      )
      |> Repo.all()

    # organizations = from(o in Picsello.Organization) |> Repo.all()
    Logger.warning("[orgs count] #{Enum.count(organizations)}")

    [
      # wedding
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "client_contact",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "client_contact",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your wedding photography with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:
        {{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # newborn
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your newborn photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:
        {{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "Our Shoot Tomorrow|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # family
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your family photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # mini-session
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your mini photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # headshot
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your headshot photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link: {{gallery_link}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: {{password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # portrait
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your portrait photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # boudoir
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # other
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # maternity
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # event
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_thank_you_lead"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        <p>Warm regards,</p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. {{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_booking_proposal_sent"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans? | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "pays_retainer"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p><br></p>
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p><br></p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p><br></p>
        <p>It can be paid in advance via your secure Client Portal: {{view_proposal_button}}</p>
        <p><br></p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p><br></p>
        <p>I can't wait to work with you!</p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "pays_retainer_offline"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot - retainer marked for - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are tenatively booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. Your date will be officially booked once I receive your offline payment, and while I am currently holding this time for you I cannot do so indefinitely.</p>
        <p>Please reply to this email to coordinate offline payment of your retainer of {{payment_amount}} immediately.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} is due on {{invoice_due_date}}. You can also pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_full"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - paid in full email",
        subject_template: "Thank you for your payment! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "paid_offline_full"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - paid in full - Offline payment email",
        subject_template: "Next Steps from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_booking"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot - Thank you for booking email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        <p>{{#first_red_section}}</p>
        <p>{{/first_red_section}}</p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for tomorrow! I hope everything is going smoothly. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link: {{view_proposal_button}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "offline_payment"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead: {{view_proposal_button}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business! It would mean the world to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you’re in need of photography!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
        <p><br></p>
        <p>{{email_signature}}</p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_gallery_send_link"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Release email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: {{password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at {{gallery_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and print credits to use, please log in with the email address you received this email to. When you share the gallery with friends and family, kindly ask them to log in with their own email addresses to avoid any access issues with your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery For Selects email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link: {{album_link}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To utilize your digital image credits, please log in with the email address this email was sent to. You can also select more for purchase as well! Also, if you do share with someone else, Please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "manual_send_proofing_gallery_finals"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Proofing Gallery Finals email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password.  Please use the following password to view them: {{album_password}}. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link: {{album_link}} and you can easily download them all with a simple click. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you have still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart - follow up 2",
        subject_template:
          "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click {{client_gallery_order_page}} to complete your order.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}}, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{client_gallery_order_page}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring - follow up 2",
        subject_template:
          "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images {{gallery_link}} here.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_physical"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "order_confirmation_digital_physical"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to inform you that your order from your gallery has been successfully processed, and your beautiful digital images are ready for you to enjoy!</span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Digital Images Are Ready for Download</strong></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your digital images by clicking on the download link below. For the best experience, we recommend downloading these files on a computer.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here's the link: {{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">After downloading, simply unzip the file to access your high-quality digital images, and we advise making a backup copy to ensure their safety. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><strong style="color: rgb(0, 0, 0);">Your Print Products Are Now in Production</strong></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting {{client_gallery_order_page}}.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "digitals_ready_download"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><br></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      }
    ]
    |> Enum.each(fn attrs ->
      state = get_state_by_pipeline_id(pipelines, attrs.email_automation_pipeline_id)

      attrs = Map.merge(attrs, %{state: Atom.to_string(state), inserted_at: now, updated_at: now})

      email_preset =
        from(e in email_preset_query(attrs), where: is_nil(e.organization_id)) |> Repo.one()

      if email_preset do
        email_preset |> EmailPreset.default_presets_changeset(attrs) |> Repo.update!()
      else
        attrs |> EmailPreset.default_presets_changeset() |> Repo.insert!()
        Logger.warning("[for current org] #{Enum.count(organizations) + 1} for #{attrs.job_type}")

        Enum.map(organizations, fn %{id: org_id} ->
          Logger.warning("[record inserted] #{org_id} for #{attrs.job_type}")
          Map.merge(attrs, %{organization_id: org_id})
        end)
        |> then(&Repo.insert_all("email_presets", &1))
      end
    end)
  end

  defp email_preset_query(attrs) do
    from(ep in EmailPreset,
      where:
        ep.type == ^attrs.type and
          ep.name == ^attrs.name and
          ep.job_type == ^attrs.job_type and
          ep.email_automation_pipeline_id == ^attrs.email_automation_pipeline_id
    )
  end

  defp get_pipeline_id_by_state(pipelines, state) do
    pipeline =
      pipelines
      |> Enum.filter(&(&1.state == String.to_atom(state)))
      |> List.first()

    pipeline.id
  end

  defp get_state_by_pipeline_id(pipelines, id) do
    pipeline =
      pipelines
      |> Enum.filter(&(&1.id == id))
      |> List.first()

    pipeline.state
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
