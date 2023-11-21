defmodule Mix.Tasks.ImportEmailPresets do
  @moduledoc false

  use Mix.Task
  require Logger
  import Ecto.Query

  alias Picsello.{
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
    pipelines = from(p in EmailAutomationPipeline) |> Repo.all()

    organizations = from(o in Picsello.Organization, select: %{id: o.id}) |> Repo.all()
    Logger.warning("[orgs count] #{Enum.count(organizations)}")

    [
      # wedding
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "lead",
        state: "client_contact",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your wedding on {{session_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this week is as stress-free as the week of a wedding can be for you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please can you let me know who will be my liaison on the big day. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I truly can't wait to capture your special day. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm excited for {{total_time}}! I hope everything is going smoothly. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I will be meeting you at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If we haven't already confirmed who will be the liaison, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed! </span></p>
        <p><span style="color: rgb(0, 0, 0);"> If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">This is going to be an amazing day, so please relax and enjoy this time.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please feel free to reach out!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while since your wedding and I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "wedding",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # newborn
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your family and that you will treasure for years to come.</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to  your newborn photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm sending along a reminder about how to best prepare for our upcoming shoot. Please read through as it is very helpful to our shoot!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Wardrobe</span></p>
        <p><span style="color: rgb(0, 0, 0);">Depending upon what you want from the shoot, you can choose fun, casual clothes or something more dressy. Make sure that the clothes are as timeless as possible. Creams, whites, off whites and neutrals look timeless in newborn images.  Avoid really busy logos so the photographs let your family, rather than the clothes, shine.  Please avoid onesies with wording on them (like big brother, little sister)  as well as collared shirts or dresses for newborns - they just don't photograph well.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Preparation Tips</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. The morning of your session, be sure to give the baby a bath and bring extra wipes for a last-minute nose cleaning (very important to have a clean nose!) and for eye boogers! The bath really helps for a fantastic shoot.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. They should also be fully fed (45 minutes feed) as close to you leaving for the studio as possible. Please allow up to 2-4 hours for these sessions (2 hours for bottle-fed or 4 hours+ for exclusively breastfed).</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. If you are pumping or the babies are on formula, please bring a lot of extra bottles so if they get hungry they can have a snack (don't worry it won’t make them get off schedule - they are burning more calories on a shoot so they get hungrier quicker!). Please also have their pacifier handy if they have one - these are magic to get the babies through the shoot sometimes!</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. The space where we are photographing the baby needs to be very warm–warmer than will probably be comfortable for everyone else– to keep the baby happy and sleepy. If the shoot is at your home, plan on turning up the heat or using a space heater to make the room warm.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have anything specific in mind for your session, please let me know your thoughts and I will try, if I can, to incorporate them into the shoot. It helps to know any requests before the shoot so I can prep for them in advance. Please send along any images from my website or Instagram account that you love so I can see what you are looking for from the shoot. Don't worry if you don't send any, I will work my magic!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Most importantly, in this busy time of your life I want you to slow down and relax!  I want you to enjoy this precious time and I do not rush portrait sessions. Our goal is to make you as comfortable as possible. Only then will I be able to capture the moments you will fall in love with. Following the steps above will help ensure that you will enjoy your session by getting off to a good start. The more you are prepared for your session the more you will enjoy the photo shoot process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} after the shoot date. If you need one sooner for a birth announcement, we can discuss which image you think you would like to use.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to capturing this special time with your family</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "Our Shoot {{total_time}}|{{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for your photo shoot {{total_time}} at {{session_location}} at {{session_time}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here are some last-minute tips to make your session (and your photos) amazing:</span></p>
        <p><span style="color: rgb(0, 0, 0);"><strong>Prep for the baby</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">1. I highly recommend giving the baby a bath the morning of the shoot. Tires them out so they are dreams on the shoot</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. I strongly recommend feeding the baby a FULL feed (45 mins) before the shoot - note the length of time to try to coordinate as much as possible.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. If you are able to bring bottles of pumped milk or formula I will say that the shoots where the moms are exclusively breastfeeding are 2X as long as the ones where you can just top them off with a bottle. I strongly recommend that - a game changer for the baby's experience on the shoot.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Bring a pacifier</span></p>
        <p><span style="color: rgb(0, 0, 0);"><strong>Prep for any older siblings</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Be excited.  Be happy :) It is family photo day - we are going to have lots of fun! Tell them we will be going to 'play' at the photo studio or at your home. It's Mommy and Daddy's friend - it will be so fun.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Show them photos of the last family photo shoot we did or other family photos you have so they can understand what is happening. Children don’t easily connect the experience of being in front of a camera with the images you show them later. If you can help them realize what they’re doing, they’re much more likely to participate willingly. Tell them how happy the photos made you and remind them what fun they had taking those photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Let them in on the why. For example: “We are doing this for Mommy/Daddy/Grandma /Aunt Mabel with 5 cats” or even just “We need new pictures for our walls as you have grown up so much!”</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. If your child is over age three, bribery works. Offer them a trip to the playground, a giant ice cream, or a toy for great behavior on the shoot. The offer of a reward works wonders drawing out children’s best behavior on a shoot! We can’t recommend bribery enough.</span></p>
        <p><span style="color: rgb(0, 0, 0);">5. When we start the shoot - try not to have them holding any item that you won't want in the photos. For example, If they have a lovey, a pacifier, or a sippy cup, please don't have them holding it when they get to the shoot or I may not be able to get it out of their hands, which means it’ll end up in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">6. Act excited–kids feed off any negativity so if any adult or older kid in the group isn't into getting their photo taken please just have them fake it for the shoot!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Relax! Have fun! We will have a blast and I'll capture those special moments for you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">In general, email is the best way to get a hold of me, however, If you have any issues {{total_time}} or an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on 1st birthday",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope everyone is doing well and you are loving your newborn portraits!</span></p>
        <p><span style="color: rgb(0, 0, 0);">As you know, little ones change so fast. I know how much joy it brings us to look back at the many stages of kids’ lives through beautiful photographs. I’d love the chance to document your family as they grow up!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do offer a baby's first-year package - this includes sitter session and one-year portraits and cake smash.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to let me know as soon as possible to ensure your preferred date is available. Don't miss how fast your little one grows up!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Forgive me if we already discussed this - I have to schedule automated emails or I would forget!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know as I can’t wait to see you again!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's getting close to when I usually schedule One Year Portraits so I wanted to send along a reminder to schedule your One Year Portrait session for your little one!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Forgive me if we already discussed this - I have to schedule these automated emails or I would forget!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Friendly reminder: Your Gallery is expiring soon!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "newborn",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # family
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your family and that you will treasure for years to come.</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      # insert all
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along a reminder about how to best prepare for our upcoming shoot. Please read through as it is very helpful to our shoot.</span></p>
        <p><span style="color: rgb(0, 0, 0);">What to expect at your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to be sure you give yourself a little time to get settled and finalize your look before we start shooting. Often little ones will need a snack, a nose wipe and/or a few minutes to adjust to a new environment.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Remember that to kids, a photoshoot is usually a totally new experience. They may not be themselves in front of the camera. With most childrens’ sessions the window of opportunity for great moments happens for 10-15 minutes. After that they may get nervous about being away from their parents and aren't sure of what to do with all the attention or just get bored. All of this is normal!</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Practice Patience! I do not rush the shoot or push the children into something they don’t want to do – that doesn’t make for an enjoyable experience for anyone (or a memorable photo!). Patience is key in these situations. we don’t force them to do a shot, they will usually willingly cooperate in their own time – this is where and when we get the great shots.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Most importantly, in this busy time of your life, I want you to slow down and relax! My goal is to make you as comfortable as possible. Only then will I be able to capture the moments you will fall in love with.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to prepare for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Depending upon what you want from the shoot, you can choose clothes that are fun and casual or dressy. Make sure that the clothes are timeless as possible. Avoid really busy logos and prints so the photographs really let your family, rather than the clothes, shine. If you have any questions or need help with wardrobe choices - simply let us know! I am here to help.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Children (and parents)  should be fully fed if possible. If not, please have some snacks (not candy or sugary snacks) for them while I am on the shoot! Rested and full bellies make for a happier session. Please make sure their faces are clean and free of boogers if possible! Also, please do bring a change of clothes just in case - accidents can happen!</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Following the steps above will help ensure that you will enjoy your session by getting off to a good start. The more you are prepared for your session, the more you will enjoy the photo shoot process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for your photo shoot {{total_time}} at {{session_location}} at {{session_time}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here are some last-minute tips to make your session (and your photos) amazing:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Be on time or early. Our session commences precisely at the scheduled start time. I don’t want you to miss out on any of the time you booked.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Show them photos of the last family photo shoot we did or other family photos you have so they can understand what is happening. Children don’t easily connect the experience of being in front of a camera with the images you show them later. If you can help them realize what they’re doing, they’re much more likely to participate willingly. Tell them how happy the photos made you and remind them what fun they had taking those photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Make the photoshoot seem like an adventure and not a stressful chore. Call it “Family Photo Day!” and help the kids see me as a friend.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Let them in on the "why". For example: “We are doing this for mommy/daddy/grandma/Aunt Mabel with 5 cats” or even just “We need new pictures for our walls as you have grown up so much!”</span></p>
        <p><span style="color: rgb(0, 0, 0);">5. If your child is over age three, bribery works. Offer them a trip to the playground, a giant ice cream, or a toy for great behavior on the shoot. The offer of a reward works wonders drawing out children’s best behavior on a shoot! We can’t recommend bribery enough.</span></p>
        <p><span style="color: rgb(0, 0, 0);">6. When we start the shoot - try not to have them holding any item that you won't want in the photos. For example, If they have a lovey, a pacifier, or a sippy cup, please don't have them holding it when we get to the shoot or I may not be able to get it out of their hands, which means it’ll end up in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">7. Act excited–kids feed off any negativity so if any adult or older kid in the group isn't into getting their photo taken please just have them fake it for the shoot!</span></p>
        <p><span style="color: rgb(0, 0, 0);">8. Relax! Have fun! We will have a blast and I'll capture those special moments for you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">In general, email is the best way to get a hold of me, however, If you have any issues finding me or the location {{total_time}}, or an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with your family and I just loved our shoot. Assuming you’re in the habit of taking annual family photos (and there are so many good reasons to do so) I'd love to be your photographer again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "family",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # mini-session
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating photographs that capture your family and that you will treasure for years to come.</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along a reminder about how to best prepare for our upcoming shoot. Please read through it as it is very helpful to our shoot.</span></p>
        <p><span style="color: rgb(0, 0, 0);">What to expect at your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to be sure you give yourself a little time to get settled and finalize your look before we start shooting. Often little ones will need a snack, a nose wipe, and/or a few minutes to adjust to a new environment.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Remember that to kids, a photoshoot is usually a totally new experience. They may not be themselves in front of the camera. With most children's sessions, the window of opportunity for great moments happens for 10-15 minutes. After that,  they may get nervous about being away from their parents and aren't sure of what to do with all the attention or just get bored. All of this is normal!</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Practice Patience! I do not rush the shoot or push the children into something they don’t want to do – that doesn’t make for an enjoyable experience for anyone (or a memorable photo!). Patience is key in these situations. we don’t force them to do a shot, they will usually willingly cooperate in their own time – this is where and when we get the great shots.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Most importantly, in this busy time of your life, I want you to slow down and relax! My goal is to make you as comfortable as possible. Only then will I be able to capture the moments you will fall in love with.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to prepare for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Depending upon what you want from the shoot, you can choose clothes that are fun and casual or dressy. Make sure that the clothes are as timeless as possible. Avoid really busy logos and prints so the photographs really let your family, rather than the clothes, shine. If you have any questions or need help with wardrobe choices - simply let us know! I am here to help.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Children (and parents)  should be fully fed if possible. If not, please have some snacks (not candy or sugary snacks) for them while I am on the shoot! Rested and full bellies make for a happier session. Please make sure their faces are clean and free of boogers if possible! Also, please do bring a change of clothes just in case - accidents can happen!</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Following the steps above will help ensure that you will enjoy your session by getting off to a good start. The more you are prepared for your session, the more you will enjoy the photo shoot process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for your photo shoot {{total_time}} at {{session_location}} at {{session_time}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Here are some last-minute tips to make your session (and your photos) amazing:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Be on time or early. Our session commences precisely at the scheduled start time. I don’t want you to miss out on any of the time you booked.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Show children photos of the last family photo shoot we did or other family photos you have so they can understand what is happening. They don’t easily connect the experience of being in front of a camera with the images you show them later. If you can help them realize what they’re doing, they’re much more likely to participate willingly. Tell them how happy the photos made you and remind them what fun they had taking those photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Make the photoshoot seem like an adventure and not a stressful chore. Call it “Family Photo Day!” and help the kids see me as a friend.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Let them in on the "why". For example: “We are doing this for Mommy/Daddy/Grandma/Aunt Mabel with 5 cats” or even just “We need new pictures for our walls as you have grown up so much!”</span></p>
        <p><span style="color: rgb(0, 0, 0);">5. If your child is over age three, bribery works. Offer them a trip to the playground, a giant ice cream, or a toy for great behavior on the shoot. The offer of a reward works wonders drawing out children’s best behavior on a shoot! We can’t recommend bribery enough.</span></p>
        <p><span style="color: rgb(0, 0, 0);">6. When we start the shoot - try not to have them holding any item that you won't want in the photos. For example, If they have a lovey, a pacifier, or a sippy cup, please don't have them holding it when we get to the shoot or I may not be able to get it out of their hands, which means it’ll end up in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">7. Act excited–kids feed off any negativity so if any adult or older kid in the group isn't into getting their photo taken please just have them fake it for the shoot!</span></p>
        <p><span style="color: rgb(0, 0, 0);">8. Relax! Have fun! We will have a blast and I'll capture those special moments for you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">In general, email is the best way to get a hold of me, however, If you have any issues finding me or the location {{total_time}}, or an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with your family and I just loved our shoot. Assuming you’re in the habit of taking annual family photos (and there are so many good reasons to do so) I'd love to be your photographer again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "mini",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # headshot
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating headshots that you will love!</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to plan for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Plan ahead to look and feel your best. Be sure to get a manicure, facial etc - whatever makes you feel confident. If you need hair and makeup recommendations let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Think through how these photos will be used and what you most want people who look at them to understand about you. Do you want to project strength and competence? Friendliness and approachability? Trustworthiness? It can help to think through what you want your clients or audience to feel when they see your photo by imagining sitting across from that person. What would you want to be wearing? What do you want your clients or audience to feel about you? All of this comes through in a great headshot photo.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along a few last minute tips to ensure we have a great shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to be sure you give yourself a little time to get settled and finalize your look before we start!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Be sure to drink lots of water, get good sleep tonight and eat well before your session.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Think through how these photos will be used and what you most want people who look at them to understand about you. Do you want to project strength and competence? Friendliness and approachability? Trustworthiness? It can help to think through what you want your clients or audience to feel when they see your photo by imagining sitting across from that person. All of this comes through in a great headshot photo.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. I wanted to check in to see if you have any other photography needs (or want another headshot!).</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "headshot",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # portrait
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating portraits that you will love!</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to plan for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Plan ahead to look and feel your best. Be sure to get a manicure, facial etc - whatever makes you feel confident. If you need hair and makeup recommendations let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Think through how these photos will be used and what you most want people who look at them to understand about you. What would you want to be wearing? What do you want your audience to feel about you? All of this comes through in a great portrait.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">A few last minute tips so we can have the best shoot possible:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to be sure you give yourself a little time to get settled and finalize your look before we start!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Be sure to drink lots of water, get good sleep tonight and eat well before your session.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Think through how these photos will be used and what you most want people who look at them to understand about you. Do you want to project strength and competence? Friendliness and approachability? Trustworthiness? It can help to think through what you want your clients or audience to feel when they see your photo by imagining sitting across from that person. All of this comes through in a great portrait.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. I wanted to check in to see if you have any other photography needs (or want another portrait!).</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "portrait",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # boudoir
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating portraits that you will love!</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to plan for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Plan ahead to look and feel your best. Be sure to get a manicure, facial etc - whatever makes you feel confident. If you need hair and makeup recommendations let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Think through how these photos will be used and what you most want people who look at them to understand about you. What would you want to be wearing? What do you want your audience to feel about you? All of this comes through in a great boudoir portrait.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">A few last minute tips so we can have the best shoot possible:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to give yourself a little time to get settled and finalize your look before we start!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Be sure to drink lots of water, get good sleep tonight and eat well before your session.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Think through how these photos will be used and what you most want people who look at them to understand about you. Are they just for you? Do you want to project strength and competence? It can help to think through what you want your clients or audience to feel when they see your photo by imagining sitting across from that person. All of this comes through in a great photograph.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Can't wait!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. I wanted to check in to see if you have any other photography needs (or want another boudoir portrait!).</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "boudoir",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # other
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating portraits that you will love!</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to plan for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Plan ahead to look and feel your best. Be sure to get a manicure, facial etc - whatever makes you feel confident. If you need hair and makeup recommendations let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Think through how these photos will be used and what you most want people who look at them to understand about you. What would you want to be wearing? What do you want your audience to feel about you? All of this comes through in a great portrait.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In general, email is the best way to get a hold of me, however, If you have any issues finding me or the photoshoot location {{total_time}}, or there is an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """

        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. I wanted to check in to see if you have any other photography needs.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "other",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # maternity
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to creating portraits that you will love!</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">How to plan for your shoot:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Plan ahead to look and feel your best. Be sure to get a manicure, facial etc - whatever makes you feel confident. If you need hair and makeup recommendations let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Think through how these photos will be used and what you most want people who look at them to understand about you. What would you want to be wearing? What do you want your audience to feel about you. All of this comes through in the final artwork.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along some last-minute tips to ensure we have a great shoot!</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Please arrive at your shoot on time or a few minutes early to be sure you give yourself a little time to get settled and finalize your look before we start!</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Be sure to drink lots of water, get good sleep tonight and eat well before your session.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Don’t stress! We are working together to make these photos. I will help guide you through the process to ensure that you look amazing in your photos.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. Assuming you’re in the habit of taking annual family photos (and there are so many good reasons to do so) I’d love to be your photographer again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "maternity",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      },
      # event
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "client_contact"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Lead - Auto reply email to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to working with you and appreciate your patience. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Follow-up on Your Photography Inquiry",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I haven't heard back from you so I wanted to drop a friendly follow-up.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any lingering questions or if there's anything more I can do to help you, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm looking forward to your response and the possibility of working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, and the to-do list never seems to end. I'm just following up on your recent inquiry with me, and I'm excited about working with you. Please hit the reply button to this email and let me know how I can assist you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm here to ensure that your photography experience is nothing short of memorable!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        name: "Lead - Initial Inquiry",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are well. I'm reaching out one last time to inquire whether you are still interested in working with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've chosen to explore alternative options or if your priorities have evolved, I completely understand. Life has a way of keeping us busy!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please don't hesitate to get in touch if you have any questions or if you'd like to revisit the idea of working together in the future.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best wishes,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Thank you for inquiring! </span> I am thrilled to hear from you and am looking forward to capturing your special event.</p>
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
        <p><span style="color: rgb(0, 0, 0);">I am excited to work with you! Here’s how to officially book your photo session:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Pay your retainer</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</span></p>
        <p><span style="color: rgb(0, 0, 0);">When you’re officially booked, look for a confirmation email from me with more details! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Final Step to Secure Your Booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I trust you're doing well. Recognizing that life can become quite hectic, I wanted to touch base as I've noticed that you haven't yet completed the official booking process.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Until your booking is confirmed, the date and time we discussed remains available to other potential clients. To secure my services at the agreed rate and time, kindly follow these straightforward steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Complete the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment.</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should there have been any changes or if you have any questions, please don't hesitate to get in touch. I'm here to provide any assistance you may require.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Friendly Reminder: Final Step to Secure Your Booking",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I understand that life can get busy, so I wanted to send a friendly reminder regarding the final step to secure your booking with me.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As of now, the date and time we discussed are still available to other potential clients until your booking is confirmed. To ensure that we're set to capture your special moments at the agreed rate and time, please take a moment to complete these simple steps:</span></p>
        <p><span style="color: rgb(0, 0, 0);">1. Review your proposal.</span></p>
        <p><span style="color: rgb(0, 0, 0);">2. Carefully read and sign your contract.</span></p>
        <p><span style="color: rgb(0, 0, 0);">3. Fill out the initial questionnaire.</span></p>
        <p><span style="color: rgb(0, 0, 0);">4. Make your retainer payment. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you've encountered any changes or if you have any questions at all, please don't hesitate to reach out to me. I'm here to assist you in any way possible and make this process as smooth as possible for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "Booking Proposal Email",
        subject_template: "Change of plans?",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you're doing well. It seems I haven't received a response from you, and I know that life can sometimes lead us in different directions or bring about changes in priorities. I completely understand if that has happened. </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{view_proposal_button}} </span></p>
        <p><span style="color: rgb(0, 0, 0);">If this isn't the case and you still have an interest or any questions, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p>You are officially booked for your photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}}.</p>
        <p>It can be paid in advance via your secure Client Portal:</p>
        <p>{{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>I can't wait to work with you!</p>
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
        name: "Pre-Shoot - retainer marked for Offline payment email",
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I’m really looking forward to working with you! I see you have noted that you will pay your retainer offline. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Upon receipt of payment, you will be officially booked for your shoot on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.Thanks again for choosing {{photography_company_s_name}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
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
        subject_template: "Thank you for your payment!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Next Steps with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for your payment! Your account has been paid in full for your shoot with me on {{session_date}} at {{session_time}} at {{session_location}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to capturing this time for you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once again, thank you for choosing {{photography_company_s_name}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
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
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "thanks_job"),
        total_hours: 0,
        status: "active",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Thank you for booking email",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "{{total_time}} reminder from {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to photographing your event on {{session_date}} at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't already, please let me know who will be my liaison on the day of the event.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "before_shoot"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Pre-Shoot",
        subject_template: "The Big Day {{total_time}} | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to your photoshoot {{total_time}}  at {{session_time}} at {{session_location}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you haven't confirmed who will be the liaison, please let me know who will meet me on arrival!</span></p>
        <p><span style="color: rgb(0, 0, 0);">In general, email is the best way to get ahold of me, however, If you have any issues finding me {{total_time}}, or an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I am looking forward to working with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">To make this process easier for you, kindly complete the payment securely through your Client Portal by clicking on the following link:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "balance_due_offline"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. </span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm sending along a reminder about an upcoming payment due in the amount of {{payment_amount}} for the services scheduled on {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please reply to this email to coordinate your offline payment of {{payment_amount}}. If it is more convenient, you can simply pay via your secure Client Portal instead:</span></p>
        <p>{{view_proposal_button}}</p>
        <p><span style="color: rgb(0, 0, 0);">Following this payment, there will be a remaining balance of {{remaining_amount}}, with the subsequent payment of {{invoice_amount}} scheduled for {{invoice_due_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "shoot_thanks"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks for a great shoot yesterday. I enjoyed working with you and we’ve captured some great images.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions in the meantime, please don’t hesitate to let me know.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Follow up on gallery products",
        subject_template: "Checking in!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. I'm just checking in to see if you are enjoying the images from our session a few months ago.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you are interested in additional gallery products, let me know as I would be more than happy to provide some image and product recommendations.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I appreciate your business and would love the opportunity to work with you again.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "post_shoot"),
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "job",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you are doing well. It's been a while!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I loved spending time with you and I just loved our shoot. I wanted to check in to see if you have any other photography needs.</span></p>
        <p><span style="color: rgb(0, 0, 0);">I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply reply to this email and we can get your next shoot on the calendar!</span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait to see you again!</span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Great news – your gallery is now available!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please remember that your photos are password-protected, and you'll need this password to access them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery to view all your images at:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any digital image and/or print credits to use, please be sure to log in with the email address to which this email was sent. When you share the gallery with friends and family, kindly ask them to log in with their unique email addresses to ensure only you have access to those credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your gallery will be available until {{gallery_expiration_date}}, so please ensure you make your selections before then.</span></p>
        <p><span style="color: rgb(0, 0, 0);">It's been a pleasure working with you, and I'm eagerly awaiting your thoughts!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
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
        subject_template: "Your Proofing Album is ready!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to let you know that your proofs are now ready for your viewing pleasure! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep in mind that your photos are under password protection for your privacy. You can use the following password to access them: {{album_password}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your proofing album by clicking on the following link:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">To use any digital image credits, please be sure to log in with the email address to which this email was sent. You can also select more for purchase as well! If you do share the gallery with someone else, please ask them to use their own email address when logging in to prevent any issues related to your credits.</span></p>
        <p><span style="color: rgb(0, 0, 0);">In order to select the photos you'd like to move forward with retouching, simply choose each image and complete the checkout process by selecting "Send to Photographer." </span></p>
        <p><span style="color: rgb(0, 0, 0);">﻿Once that's done, I'll proceed with the full editing and send them your way. If you have any questions, please let me know I am happy to help you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can't wait to see which ones you choose! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
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
        subject_template: "Your Gallery is ready! ",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm delighted to share that your retouched images are now available! </span></p>
        <p><span style="color: rgb(0, 0, 0);">To maintain the privacy of your photos, they are protected by a password. Please use the following password to view them: {{album_password}}. </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your Finals album by clicking on the following link and you can easily download them all with a simple click:</span> {{album_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope you love your images as much as I do!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart email",
        subject_template: "Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I noticed that you still have items in your cart! I wanted to see if you had any questions, if you do - simply reply to this email and I can help you.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If life got busy, simply just click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to remind you that your recent order from {{photography_company_s_name}} is still pending in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">To finalize your order, please click on the following link:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Completing your purchase will confirm your order and initiate production.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or require assistance, please don't hesitate to reach out to me!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks!</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>

        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "cart_abandoned"),
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Abandoned Cart",
        subject_template: "Reminder: Your order with {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Another friendly reminder that you still have an order from {{photography_company_s_name}} waiting in your cart.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click on the following link to complete your order:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Your order will be confirmed and sent to production as soon as you complete your purchase.</span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Warm regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring email",
        subject_template: "Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to remind you that your gallery is nearing its expiration date. To ensure you don't miss out, please take a moment to log into your gallery and make your selections before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">As a quick reminder, your photos are protected with a password, so you'll need to enter it to view them: <strong>{{password}}</strong> </span></p>
        <p><span style="color: rgb(0, 0, 0);">You can access your private gallery containing all of your images by following this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions or need assistance with anything related to your gallery, please don't hesitate to reach out. I'm here to help! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template:
          "Friendly reminder: Your Gallery is expiring soon! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm following up with another reminder that the expiration date for your gallery is approaching. To ensure you have ample time to make your selections, please log in to your gallery and make your choices before it expires on {{gallery_expiration_date}}.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily access your private gallery, where all your images are waiting for you, by clicking on this link:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Just a quick reminder, your photos are protected with a password for your privacy and security. To access your images, simply use the provided password: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">If you need help or have any questions, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_expiration_soon"),
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Expiring",
        subject_template: "Last Day to get your photos and products!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to send along one last reminder in case you forgot! Your gallery is going to expire {{total_time}}! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">A reminder your photos are password-protected, so you will need to use this password to view: <strong>{{password}}</strong></span></p>
        <p><span style="color: rgb(0, 0, 0);">You can log into your private gallery to see all of your images here:</span> {{gallery_link}}</p>
        <p><span style="color: rgb(0, 0, 0);">Any questions, please let me know! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "gallery_password_changed"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template:
          "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your Gallery password has been successfully changed. If you did not make this change, please let me know!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id:
          get_pipeline_id_by_state(pipelines, "after_gallery_send_feedback"),
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Gallery - Request for Google Review email",
        subject_template: "Feedback is my love language!",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I had an absolute blast photographing you and would love to hear from you about your experience.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Are you enjoying your photos? Do you need help picking products for your photos? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on Google will really help my small business! It would mean the world to me! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I look forward to hearing from you again next time you're in need of photography!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}} </span></p>
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
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download).</span></p>
        <p><span style="color: rgb(0, 0, 0);"> {{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer. We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
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
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congratulations on successfully placing an order from your gallery! I'm truly excited for you to have these beautiful images in your hands!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order is now in the production phase and is being prepared with great care. You can easily track the order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digitals and/or Products) Order Received",
        subject_template: "Your gallery order confirmation! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I'm thrilled to confirm your gallery order from {{photography_company_s_name}} has been successfully processed.</span></p>
        <p><span style="color: rgb(0, 0, 0);">- If you have ordered digital images, you can expect to receive a follow-up email with your images. Since these files can be quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">-If you have ordered print products,  your order is now in production and is being prepared with great care.</span></p>
        <p><span style="color: rgb(0, 0, 0);">You can easily track the progress of your order by visiting:</span> {{client_gallery_order_page}}</p>
        <p><span style="color: rgb(0, 0, 0);">Should you have any questions or need further assistance regarding your order, please don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        <p><span style="color: rgb(0, 0, 0);">I hope this message finds you well. I wanted to let you know that your digital images are currently being prepared for download. Since these files are quite large, it may take a little time to package them properly.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Please keep an eye on your email, as you can expect to receive another message with a download link to your digital image files in the next 30 minutes. </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you encounter any issues or have questions about the download, don't hesitate to reach out.</span></p>
        <p><span style="color: rgb(0, 0, 0);">Best regards,</span></p>
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
        name: "(Digital) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Congrats! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Your digital images from {{photography_company_s_name}} are ready! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Simply click the download link below to download your files now (computer highly recommended for the download) </span></p>
        <p><span style="color: rgb(0, 0, 0);"><span class="ql-cursor">﻿</span>{{download_photos}}</span></p>
        <p><span style="color: rgb(0, 0, 0);">Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible. </span></p>
        <p><span style="color: rgb(0, 0, 0);"> </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer! </span></p>
        <p><span style="color: rgb(0, 0, 0);">If you have any questions, please let me know. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_shipped"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">Your order has shipped and it is now on it's way to you! </span></p>
        <p><span style="color: rgb(0, 0, 0);">I can’t wait for you to have your images in your hands! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Please let me know if you have any questions! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks! </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_delayed"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I wanted to let you know that your order has unfortunately been delayed. I am working with my printer to get them to you as soon as I can. I will keep you updated on the ETA. Apologies for the delay! </span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks in advance, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "order_arrived"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "gallery",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p><span style="color: rgb(0, 0, 0);">Hello {{order_first_name}},</span></p>
        <p><span style="color: rgb(0, 0, 0);">I see that your order has been delivered! I truly can't wait for you to see your products. </span></p>
        <p><span style="color: rgb(0, 0, 0);">Also, I would love to see the finished product so to speak, so please send me images when you have them!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Thanks again for choosing me as your photographer, it was a pleasure to work with you!</span></p>
        <p><span style="color: rgb(0, 0, 0);">Kind regards, </span></p>
        <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
        """
      },
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, "abandoned_emails"),
        total_hours: 0,
        status: "disabled",
        job_type: "event",
        type: "lead",
        position: 0,
        name: "Abandoned Booking Event Email",
        subject_template:
          "Complete Your Booking for Your Session with {{photography_company_s_name}}",
        body_template: """
        <p>Hi {{client_first_name}}</p>
        <p>I hope this email finds you well. I noticed that you recently started the booking process for a photography session with {{photography_company_s_name}}, but it seems that your booking was left incomplete.</p>
        <p>I understand that life can get busy, and I want to make sure you don't miss out on capturing those special moments.</p>
        <p>To complete your booking now, simply follow this link: {{booking_event_client_link}}
        <p>{{email_signature}}</p>
        """
      }
    ]
    |> insert_presets(pipelines, organizations)
  end

  def insert_presets(emails, pipelines, organizations) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    emails
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

  def assign_default_presets_new_user(organization_id) do
    email_presets =
      get_all_default_email_presets()
      |> Enum.map(fn map ->
        map
        |> Map.from_struct()
        |> Map.drop([
          :id,
          :immediately,
          :is_global,
          :count,
          :calendar,
          :sign,
          :short_codes,
          :template_id,
          :email_automation_pipeline,
          :organization,
          :__meta__
        ])
        |> Map.replace(:state, Map.get(map, :state) |> Atom.to_string())
        |> Map.replace(:status, Map.get(map, :status) |> Atom.to_string())
        |> Map.replace(:type, Map.get(map, :type) |> Atom.to_string())
        |> Map.replace(:inserted_at, DateTime.utc_now())
        |> Map.replace(:updated_at, DateTime.utc_now())
        |> Map.put(:organization_id, organization_id)
      end)

    Repo.insert_all("email_presets", email_presets)
  end

  # defp update_all_org_presets(organizations, attrs, email_preset) do
  #   Enum.map(organizations, fn %{id: org_id} ->
  #     Logger.warning("[record updated] #{org_id} for #{email_preset.job_type}")

  #     email_preset =
  #       from(e in email_preset_query(attrs), where: e.organization_id == ^org_id)
  #       |> Repo.one()

  #     if email_preset do
  #       email_preset
  #       |> EmailPreset.default_presets_changeset(Map.merge(attrs, %{organization_id: org_id}))
  #       |> Repo.update!()
  #     end
  #   end)
  # end

  defp get_all_default_email_presets() do
    from(ep in EmailPreset, where: is_nil(ep.organization_id)) |> Repo.all()
  end

  defp email_preset_query(attrs) do
    from(ep in EmailPreset,
      where:
        ep.type == ^attrs.type and
          ep.subject_template == ^attrs.subject_template and
          ep.name == ^attrs.name and
          ep.job_type == ^attrs.job_type and
          ep.email_automation_pipeline_id == ^attrs.email_automation_pipeline_id and
          ep.total_hours == ^attrs.total_hours
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
