defmodule Mix.Tasks.ImportEmailPresets do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, EmailPresets.EmailPreset}
  import Ecto.Query

  @shortdoc "import email presets"
  def run(_) do
    load_app()

    insert_emails()
  end

  def insert_emails() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    [
      # wedding
      %{
        email_automation_pipeline_id: 1,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Auto reply to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p>Hello {{client_first_name}}!</p>
        <p>Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can!</p>
        <p>I look forward to working with you and appreciate your patience.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You inquired recently about {{photography_company_s_name}} photographing your wedding.</p>
        <p>Since I haven’t heard back from you, I wanted to see if there were any questions I didn’t answer in my previous email, or if there’s something else I can do to help you with your photography needs for your Wedding.</p>
        <p>I'd love to help you capture the photos of your dream day.</p>
        <p>Looking forward to hearing from you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You inquired recently about {{photography_company_s_name}} photographing your wedding.</p>
        <p>I'd still love to help. Hit reply to this email and let me know what I can do for you!</p>
        <p>Looking forward to it!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I haven’t yet heard back from you, so I have assumed you've gone in a different direction or your priorities have changed.</p>
        <p>If that is not the case, simply let me know as I understand life gets busy!</p>
        <p>Cheers!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 22,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for inquiring with {{photography_company_s_name}}. I am thrilled to hear from you and am looking forward to creating photographs that capture your special day and that you will treasure for years to come.</p>
        <p style="color: red;">Insert a sentence or two about your brand, what sets you apart and why you love photographing weddings.</p>
        <p style="color: red;">Try to preempt any questions you think they might have:</p>
        <p style="color: red;">1. What is your process? Do you want to schedule a call with them? Meet in person?</p>
        <p style="color: red;">2. Try to answer any frequently asked questions that often come up</p>
        <p style="color: red;">3. If you have a pricing guide, scheduling link or FAQ page link you can simply insert them as hyperlinks in the email body!</p>
        <p>When is your wedding date? Please reply to this email so we can check our availability for that date!</p>
        <p>I am looking forward to hearing from you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to photographing your wedding so you can remember this time in your life for years to come.</p>
        <p>Here’s how to officially book:</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>Your wedding photography will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</p>
        <p>When you’re officially booked, look for a confirmation email from me with more details.</p>
        <p>I can’t wait to capture this special day for you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to working with you, but noticed that you haven’t officially booked.</p>
        <p>Until officially booked, the time and date we discussed CAN be scheduled by other clients. As of this email your wedding date is available. Please sign your contract and pay your retainer to become officially booked.</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>I want everything about your wedding day to go as smoothly as possible.</p>
        <p>If something else has come up or if you have additional questions, please let me know right away.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your wedding date is still available and I do want to be your photographer. However, I haven’t heard back from you.</p>
        <p>If you still want to book your wedding with me at the rate and at the time and date we discussed, you can do so for the next 24 hours at the following link:</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>If something else has happened or your needs have changed, I'd love to talk about it and see if there’s another way I can help.</p>
        <p>Looking forward to hearing from you either way.</p>
        <p>Best,</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans?| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I haven’t heard back from you so I assume you have gone a different direction or your priorities have changed.  If that's not the case, please let me know!</p>
        <p>Best,</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p>You are officially booked for your wedding photography with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}} can be paid in advance via your secure Client Portal:
        {{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - retainer marked for OFFLINE Payment",
        subject_template: "Receipt from {{photography_company_s_name}}",
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
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - Thank you for booking",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are officially booked your wedding photography on {{session_date}} at {{session_time}} at {{session_location}}. I'm so looking forward to working with you leading up to your wedding as well as capturing your special day.</p>
        <p>A reminder your images will be delivered via a beautiful online gallery within {{delivery_time}}.</p>
        <p>I will be in touch shortly with next steps!</p>
        <p>Any questions, please feel free let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 5,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "One week reminder from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to photographing your wedding on {{session_date}}.</p>
        <p>I will be meeting you at {{session_time}} at {{session_location}}.</p>
        <p>I hope this week is as stress-free as the week of a wedding can be for you!</p>
        <p style="color: red;">Perhaps include a last minute reminder of the shot list they wanted, the wedding day schedule, confirm who will be the liasions (with their contact info) on the day to help guide you with the people/key moments.</p>
        <p>I truly can't wait to capture your special day.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 5,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "The Big Day Tomorrow | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I'm excited for tomorrow! I hope everything is going smoothly.</p>
        <p>I will be meeting you at {{session_time}} at {{session_location}}.</p>
        <p>A reminder to please have any items you would like photographed (rings, invitations, shoes, dress, other jewelry) set aside so I can begin photographing those items as soon as I arrive.</p>
        <p>If we haven't already confirmed who will be the liasions, please let me know who will meet me on arrival and help me to identify people and moments on your list of desired photographs. Please understand that if no one is available to assist in identifying people or moments on the list they might be missed!</p>
        <p>If you have any emergencies or changes, you can reach me at {{photographer_cell}}.</p>
        <p>This is going to be an amazing day, so please relax and enjoy this time.</p>
        <p>If you have any questions, please feel free to reach out!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 6,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You have a payment due in the amount of {{payment_amount}} to {{photography_company_s_name}} for your wedding photography {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>Please pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} will be due on {{invoice_due_date}}.</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 7,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Client paid in full email",
        subject_template: "Your account is now paid in full.| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your account has been paid in full for your wedding photography with me on {{session_date}} at {{session_time}} at {{session_location}}.</p>
        <p>I am looking forward to capturing this time for you.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 8,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Balance due - Offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You have an offline payment due in the amount of {{payment_amount}} to {{photography_company_s_name}} for your wedding photography {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>Please reply to this email to coordinate your offline payment of {{payment_amount}} immediately. If it is more convenient, you can pay via your secure Client Portal instead:
        {{view_proposal_button}}.</p>
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} will be due on {{invoice_due_date}}.</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 7,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Client paid offline payment email",
        subject_template: "Your account is now paid in full.| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your account has been paid in full for your wedding photography with me on {{session_date}} at {{session_time}} at {{session_location}}.</p>
        <p>I am looking forward to capturing this time for you.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 9,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your wedding yesterday was absolutely amazing. I enjoyed working with you, as well as your families and friends. I’m thrilled that we captured some great images!</p>
        <p>Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</p>
        <p>If you have any questions in the meantime, please don’t hesitate to let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 10,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "Checking in! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I had an absolute blast photographing your Wedding recently and would love to hear from you about your experience.</p>
        <p>Are you enjoying your photos? Do you need any help choosing the right products? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget!</p>
        <p>Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business!  <span style="color:red;">"Insert your google review link here"</span>  It would mean the world to me!</p>
        <p>Thanks again! I look forward to hearing from you again next time you’re in need of photography!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 10,
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I hope you are doing well. It's been a while since your wedding, and I miss you! I’d love to talk with you if you’re ready for some anniversary portraits, family photos, or any other photography needs!</p>

        <p>I also offer the following  <span style="color:red;">"insert your services link here"</span>  and my current price list for these sessions can be found in my pricing guide  <span style="color:red;">"insert your pricing link here"</span>.</p>
        <p>I do book up months in advance, so be sure to get started as soon as possible to ensure your preferred date is available. Simply book directly here <span style="color:red;">"insert your scheduling page link here"</span>.</p>
        <p>Reply to this email if you don't see a date you need or if you have any questions!</p>
        <p>I can’t wait to see you again!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Release Email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is ready!</p>
        <p>Log into your private gallery to see all of your images at {{gallery_link}}.</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{password}}</b></p>
        <p>To access any potential digital image and print credits, log in with the email address provided in this email. Share the gallery with friends and family, but ask them to log in using their own email to prevent access to credits unless specified.</p>
        <p>Your gallery expires on <b>{{gallery_expiration_date}}</b>, please make your selections before then.</p>
        <p>It’s been a delight working with you and I can’t wait to hear what you think!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Proofing Gallery For Selects Email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your proofs are ready to view! You can view your proofing album here: {album_link}}</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>
        <p>To access any potential digital image and print credits, log in with the email address provided in this email. Share the gallery with friends and family, but ask them to log in using their own email to prevent access to credits unless specified.</p>
        <p>To make the photo selections you’d like to purchase and proceed with retouching, you will need to select each image and complete checkout in order to "Send to Photographer."</p>
        <p>Then I’ll get these fully edited and sent over to you.</p>
        <p>Hope you love them as much as I do!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Proofing Gallery Finals Email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your final, retouched images are ready to view! You can view your Finals album here:{{album_link}}</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>
        <p>These photos have all been retouched, and you can download them all at the touch of a button.</p>
        <p>Hope you love them as much as I do!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email",
        subject_template: "Finish your order from {{photography_company_s_name}}!",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        <p>It’s been a delight working with you and I can’t wait to hear what you think!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are still waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        <p>Cheers!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email - follow up 2",
        subject_template: "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are still waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        <p>If you have any questions please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is about to expire! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email - follow up 1",
        subject_template: "Don't forget your gallery! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is about to expire! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email - follow up 2",
        subject_template: "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 14,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template: "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 16,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your image download files are ready:</p>
        <p>1. Click the download link below to download your files now (computer highly recommended for the download) {{download_photos}}</p>
        <p>2. Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible.</p>
        <p>3. Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer!</p>
        <p>If you have any questions, please let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 15,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your products are headed to production now. You can track your order via your {{client_gallery_order_page}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 17,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your products are headed to production now. You can track your order via your {{client_gallery_order_page}}.</p>
        <p>Your image download files are ready:</p>
        <p>1. Click the download link below to download your files now (computer highly recommended for the download) {{download_photos}}</p>
        <p>2. Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible.</p>
        <p>3. Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer!</p>
        <p>If you have any questions, please let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 18,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Digital) Order Being Prepared",
        subject_template: "Your order is being prepared. | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The download for your high-quality digital images is currently being packaged as those are large files and take some time to prepare. Look for another email with your digital image files in the next 30 minutes.{{client_gallery_order_page}}.</p>
        <p>Thank you for your purchase.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 18,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Digital and Products) Images now available",
        subject_template: "Your digital images are ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your digital image download files are ready:</p>
        <p>1. Click the download link below to download your files now (computer highly recommended for the download) {{download_photos}}</p>
        <p>2. Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible.</p>
        <p>3. Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer!</p>
        <p>You can review your order via your {{client_gallery_order_page}}.</p>
        <p>If you have any questions, please let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 19,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} are now on their way to you! I can’t wait for you to have your images in your hands!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 20,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} have been delayed. I will keep you updated on the ETA. Apologies for the delay it is out of my hands but I am working with the printer to get them to you as soon as we can!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 21,
        total_hours: 0,
        status: "active",
        job_type: "wedding",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} have arrived! I can't wait for you to see your products. I would love to see them in your home so please send me images when you have them!</p>
        {{email_signature}}
        """
      },
      # newborn
      %{
        email_automation_pipeline_id: 1,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Auto reply to contact form submission",
        subject_template: "{{photography_company_s_name}} received your inquiry!",
        body_template: """
        <p>Hello {{client_first_name}}!</p>
        <p>Thank you for your interest in {{photography_company_s_name}}. I just wanted to let you know that I have received your inquiry but am away from my email at the moment and will respond as soon as I physically can!</p>
        <p>I look forward to working with you and appreciate your patience.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You inquired recently about newborn photos with {{photography_company_s_name}}.</p>
        <p>Since I haven’t heard back from you, I wanted to see if there were any questions I didn’t answer in my previous email, or if there’s something else I can do to help you with your photography needs.</p>
        <p>I'd love to help you capture the photos of your dreams.</p>
        <p>Looking forward to hearing from you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You inquired recently about newborn photos with {{photography_company_s_name}}.</p>
        <p>I'd still love to help. Hit reply to this email and let me know what I can do for you!</p>
        <p>Looking forward to it!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 1,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry - follow up 3",
        subject_template: "One last check-in | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I haven’t yet heard back from you, so I have assumed you've gone in a different direction or your priorities have changed.</p>
        <p>If that is not the case, simply let me know as I understand life gets busy!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 22,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Lead - Initial Inquiry email",
        subject_template: "Thank you for inquiring with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for inquiring with {{photography_company_s_name}}. I am thrilled to hear from you and am looking forward to creating photographs that you and your family will treasure for years to come.</p>
        <p style="color: red;">Insert a sentence or two about your brand, what sets you apart and why you love photographing newborns.</p>
        <p style="color: red;">Try to preempt any questions you think they might have:</p>
        <p style="color: red;">- What is a session like with you?</p>
        <p style="color: red;">- How much does a session cost</p>
        <p style="color: red;">- How do they book? Can they book directly on your scheduling page?</p>
        <p style="color: red;">- Any frequently asked questions that often come up (best time to photograph newborns, who can be in the session, safety training, your experience working with newborns)</p>
        <p>If you have a pricing guide, scheduling link or FAQ page link you can simply insert them as hyperlinks in the email body!</p>
        <p>I am looking forward to hearing from you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal email",
        subject_template: "Booking your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to making amazing photographs so you can remember this time in your family’s life for years to come.</p>
        <p>Here’s how to officially book your photo session:</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>Your session will not be considered officially booked until the contract is signed and a retainer is paid. Once you are officially booked, the date and time of your photo session will be held for you and all other inquiries will be declined. For this reason, your retainer is non-refundable.</p>
        <p>When you’re officially booked, look for a confirmation email from me with more details about your session.</p>
        <p>I can’t wait to make some amazing photographs with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 1",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to working with you, but noticed that you haven’t officially booked your session.</p>
        <p>Until officially booked, the session time and date we discussed can be scheduled by other clients. As of this email your session time/date is available. Please sign your contract and pay your retainer to become officially booked.</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>I want everything about your photoshoot to go as smoothly as possible. </p>
        <p>If something else has come up or if you have additional questions, please let me know right away. </p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(4, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 2",
        subject_template: "It's me again!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>The session date we’ve been discussing is still available and I do want to be your photographer. However, I haven’t heard back from you. </p>
        <p>If you still want to book the session at the rate and at the time and date we discussed, you can do so for the next 24 hours at the following links:</p>
        <p>1. Review your proposal.</p>
        <p>2. Read and sign your contract</p>
        <p>3. Fill out the initial questionnaire</p>
        <p>4. Pay your retainer.</p>
        {{view_proposal_button}}
        <p>If something else has happened or your needs have changed, I'd love to talk about it and see if there’s another way I can help.</p>
        <p>Looking forward to hearing from you either way.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 2,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "lead",
        state: "gallery_send_link",
        position: 0,
        name: "Booking Proposal Email - follow up 3",
        subject_template: "Change of plans?| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I haven’t heard back from you so I assume you have gone a different direction or your priorities have changed.  If that's not the case, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - retainer paid email",
        subject_template: "Receipt from {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thank you for paying your retainer in the amount of {{payment_amount}} to {{photography_company_s_name}}.</p>
        <p>You are officially booked for your newborn photoshoot with me {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>You have a balance remaining of {{remaining_amount}}. Your next invoice of {{invoice_amount}} is due on {{invoice_due_date}} can be paid in advance via your secure Client Portal:
        {{view_proposal_button}}</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - retainer marked for OFFLINE Payment",
        subject_template: "Receipt from {{photography_company_s_name}}",
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
        email_automation_pipeline_id: 3,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - Thank you for booking",
        subject_template: "Thank you for booking with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You are officially booked your newborn photography on {{session_date}} at {{session_time}} at {{session_location}}. I'm so looking forward to working with you leading up to your newborn as well as capturing your special day.</p>
        <p>A reminder your images will be delivered via a beautiful online gallery within {{delivery_time}}.</p>
        <p>I will be in touch shortly with next steps!</p>
        <p>Any questions, please feel free let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 5,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - week before email",
        subject_template: "Prepping for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I am looking forward to  your newborn photoshoot on {{session_date}} at {{session_time}} at {{session_location}}. I'm sending along a reminder about how to best prepare for our upcoming shoot. Please read through as it is very helpful to our shoot!</p>
        <p stype="color: red;"><span stype="font-weight: bold;">Wardrobe</span> Please tailor to create your own wardrobe guidelines.</p>
        <p>Depending upon what you want from the shoot, you can choose fun, casual clothes or something more dressy. Make sure that the clothes are timeless as possible. Creams, whites, off whites and neutrals look timeless in newborn images.  Avoid really busy logos so the photographs let your family, rather than the clothes, shine.  Please avoid onesies with wording on them (like big brother, little sister)  as well as collared shirts or dresses for newborns - they just don't photograph well.</p>
        <p style="font-weight: bold;">Preparation Tips</p>
        <p>The morning of your session, be sure to give the baby a bath and bring extra wipes for a last minute nose cleaning (very important to have a clean nose!) and for eye boogers! The bath really helps for a fantastic shoot.</p>
        <p>They should also be fully fed (45 minutes feed) as close to you leaving for the studio as possible. Please allow up to 2-4 hours for these sessions (2 hours for bottle fed or 4 hours+ for exclusively breast fed).</p>
        <p>If you are pumping or the babies are on formula, please bring a lot of extra bottles so if they get hungry they can have a snack (don't worry it won’t make them get off schedule - they are burning more calories on a shoot so they get hungrier quicker!). Please also have their pacifier handy if they have one - these are magic to get the babies through the shoot sometimes!</p>
        <p>The space where we are photographing the baby needs to be very warm–warmer than will probably be comfortable for everyone else– to keep the baby happy and sleepy. If the shoot is at your home, plan on turning up the heat or using a space heater to make the room warm.</p>
        <p>If you have anything specific in mind for your session, please let me know your thoughts and I will try, if I can, to incorporate them into the shoot. It helps to know any requests before the shoot so I can prep for them in advance. Please send along any images from my website or imstagram account that you love so I can see what you are looking for from the shoot. Don't worry if you don't send any, I will work my magic!</p>
        <p>Most importantly, in this busy time of your life I want you to slow down and relax!  I want you to enjoy this precious time and I do not rush portrait sessions. Our goal is to make you as comfortable as possible. Only then will I be able to capture the moments you will fall in love with. Following the steps above will help ensure that you will enjoy your session by getting off to a good start. The more you are prepared for your session the more you will enjoy the photo shoot process.</p>
        <p style="font-weight: bold;">A reminder of the image turnaround</p>
        <p>After your photoshoot, your images will be delivered via a beautiful online gallery within/by {{delivery_time}}. If you need one sooner for a birth announcement, we can discuss which image you think you would like to use.</p>
        <p>I look forward to capturing this special time with your family</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 5,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Pre-Shoot - day before email",
        subject_template: "Our Shoot Tomorrow|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I can’t wait for your photo shoot tomorrow at {{session_location}} at {{session_time}}.</p>
        <p>Here are some last-minute tips to make your session (and your photos) amazing:</p>
        <p style="font-weight: bold;">Prep for the baby</p>
        <p>- I highly recommend giving the baby a bath the morning of the shoot. Tires them out so they are dreams on the shoot</p>
        <p>- I strongly recommend feeding the baby a FULL feed (45 mins) before the shoot - note the length of time to try to coordinate as much as possible.</p>
        <p>- If you are able to bring bottles of pumped milk or formula I will say that the shoots where the moms are exclusively breast feeding are 2X as long as the ones where you can just top them off with a bottle. I strongly recommend that - game changer for the baby's experience on the shoot.</p>
        <p>- Bring a pacifier</p>
        <p style="font-weight: bold;">Prep for any older siblings</p>
        <p>- Be excited.  Be happy :) It is family photo day - we are going to have lots of fun! Tell them we will be going to 'play' at the photo studio or at your home. Its mommy and daddy's friend - will be so fun.</p>
        <p>-Show them photos of the last family photo shoot we did or other family photos you have so they can understand what is happening. Children don’t easily connect the experience of being in front of a camera with the images you show them later. If you can help them realize what they’re doing, they’re much more likely to participate willingly. Tell them how happy the photos made you and remind them what fun they had taking those photos.</p>
        <p>- Let them in on the why. For example: “We are doing this for mommy/daddy/grandma /Aunt Mabel with 5 cats” or even just “We need new pictures for our walls as you have grown up so much!”</p>
        <p>- If your child is over age three, bribery works. Offer them a trip to the playground, a giant ice cream, or a toy for great behavior on the shoot. The offer of a reward works wonders drawing out children’s best behavior on a shoot! We can’t recommend bribery enough.</p>
        <p>- When we start the shoot - try not to have them holding any item that you won't want in the photos. For example, If they have a lovey, a pacifier, or a sippy cup, please don't have them holding it when they get to the shoot or I may not be able to get it out of their hands, which means it’ll end up in your photos.</p>
        <p>-Act excited–kids feed off any negativity so if any adult or older kid in the group isn't into getting their photo taken please just have them fake it for the shoot!</p>
        <p>Relax! Have fun! We will have a blast and I'll capture those special moments for you!</p>
        <p>In general, email is the best way to get a hold of me, however, If you have any issues tomorrow, or an emergency, you can call or text me on the shoot day at {{photographer_cell}}.</p>
        <p>Can't wait!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 6,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - balance due email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You have a payment due in the amount of {{payment_amount}} to {{photography_company_s_name}} for your newborn photoshoot {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>Please pay via your secure Client Portal:</p>
        {{view_proposal_button}}
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} will be due on {{invoice_due_date}}.</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}, I can't wait to work with you!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 7,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Client paid in full email",
        subject_template: "Your account is now paid in full.| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your account has been paid in full for your newborn photography with me on {{session_date}} at {{session_time}} at {{session_location}}.</p>
        <p>I am looking forward to capturing this time for you.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 8,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Client selected offline payment email",
        subject_template: "Payment due for your shoot with {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>You have an offline payment due in the amount of {{payment_amount}} to {{photography_company_s_name}} for your newborn photoshoot {{#session_date}} on {{session_date}} at {{session_time}} at {{session_location}}{{/session_date}}.</p>
        <p>Please reply to this email to coordinate your offline payment of {{payment_amount}} immediately. If it is more convenient, you can pay via your secure Client Portal instead:</p>
        {{view_proposal_button}}.
        <p>You will have a balance remaining of {{remaining_amount}} and your next payment of {{invoice_amount}} will be due on {{invoice_due_date}}.</p>
        <p>If you have any questions, please don’t hesitate to let me know.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 7,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Payments - Client paid offline payment email",
        subject_template: "Your account is now paid in full.| {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your account has been paid in full for your newborn photography with me on {{session_date}} at {{session_time}} at {{session_location}}.</p>
        <p>I am looking forward to capturing this time for you.</p>
        <p>Thank you for choosing {{photography_company_s_name}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 9,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Thank you for a great shoot email",
        subject_template: "Thank you for a great shoot! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Thanks for a fantastic photo shoot yesterday. I enjoyed working with you and we’ve captured some great images.</p>
        <p>Next, you can expect to receive your images in a beautiful online gallery within {{delivery_time}} from your photo shoot. When it is ready, you will receive an email with the link and a passcode.</p>
        <p>If you have any questions in the meantime, please don’t hesitate to let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 9,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email ",
        subject_template: "Checking in!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I had an absolute blast photographing your family recently and would love to hear from you about your experience.</p>
        <p>Are you enjoying your photos? Do you need any help choosing the right products? Forgive me if you have already decided, I need to schedule these emails in advance or I might forget!</p>
        <p>Would you be willing to leave me a review? Public reviews are huge for my business. Leaving a kind review on google will really help my small business!  <span style="color:red;">"Insert your google review link here"</span>  It would mean the world to me!</p>
        <p>Thanks again! I look forward to hearing from you again next time you’re in need of photography!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 10,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Follow up & request for reviews email",
        subject_template: "How are you?|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I hope everyone is doing well and you are loving your newborn portraits!  </p>
        <p>As you know, little ones change so fast. I know how much joy it brings us to look back at the many stages of kids’ lives through beautiful photographs. I’d love the chance to document your family as you grow.</p>
        <p>So you don't miss how fast your little one grows, I do offer a baby's first year package - this includes sitter session and one year portraits and cake smash. Here is more information on the package <span style="color: red; font-style: italic;">"insert link here or write the package details below".</span></p>
        <p>I do book up months in advance, so be sure to get started as soon as possible to ensure you get your preferred date is available. Simply book directly here <span style="color: red; font-style: italic;">"insert your scheduling page link here".</span></p>
        <p>Forgive me if we already discussed this - I have to schedule automated emails or I would forget!</span>
        <p>Reply to this email if you don't see a date you need or if you have any questions!</p>
        <p>I can’t wait to see you again!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 10,
        total_hours: EmailPreset.calculate_total_hours(9, %{calendar: "Month", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "job",
        state: "gallery_send_link",
        position: 0,
        name: "Post Shoot - Next Shoot email",
        subject_template: "Hello again!|{{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>I hope everyone is doing well and you are loving your newborn portraits!</p>
        <p>As you know, little ones change so fast. I know how much joy it brings us to look back at the many stages of kids’ lives through beautiful photographs. I’d love the chance to document your family as you grow.</p>
        <p>So you don't miss how fast your little one grows, I do offer a baby's first year package - this includes sitter session and one year portraits and cake smash. Here is more information on the package <span style="color: red; font-style: italic;">"insert link here or write the package details below".</span></p>
        <p>I do book up months in advance, so be sure to get started as soon as possible to ensure you get your preferred date is available. Simply book directly here <span style="color: red; font-style: italic;">"insert your scheduling page link here".</span></p>
        <p>Forgive me if we already discussed this - I have to schedule automated emails or I would forget!</p>
        <p>Reply to this email if you don't see a date you need or if you have any questions!</p>
        <p>I can’t wait to see you again!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Release Email",
        subject_template: "Your Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is ready!</p>
        <p>Log into your private gallery to see all of your images at {{gallery_link}}.</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{password}}</b></p>
        <p>To access any potential digital image and print credits, log in with the email address provided in this email. Share the gallery with friends and family, but ask them to log in using their own email to prevent access to credits unless specified.</p>
        <p>Your gallery expires on <b>{{gallery_expiration_date}}</b>, please make your selections before then.</p>
        <p>It’s been a delight working with you and I can’t wait to hear what you think!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Proofing Gallery For Selects Email",
        subject_template: "Your Proofing Album is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your proofs are ready to view! You can view your proofing album here: {album_link}}</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>
        <p>To access any potential digital image and print credits, log in with the email address provided in this email. Share the gallery with friends and family, but ask them to log in using their own email to prevent access to credits unless specified.</p>
        <p>To make the photo selections you’d like to purchase and proceed with retouching, you will need to select each image and complete checkout in order to "Send to Photographer."</p>
        <p>Then I’ll get these fully edited and sent over to you.</p>
        <p>Hope you love them as much as I do!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 11,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Proofing Gallery Finals Email",
        subject_template: "Your Finals Gallery is ready! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your final, retouched images are ready to view! You can view your Finals album here:{{album_link}}</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>
        <p>These photos have all been retouched, and you can download them all at the touch of a button.</p>
        <p>Hope you love them as much as I do!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Hour", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email",
        subject_template: "Finish your order from {{photography_company_s_name}}!",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email - follow up 1",
        subject_template: "Don't forget your products from {{photography_company_s_name}}!",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are still waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 12,
        total_hours: EmailPreset.calculate_total_hours(2, %{calendar: "Day", sign: "+"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Abandoned Cart Email - follow up 2",
        subject_template: "Any questions about your  products from {{photography_company_s_name}}?",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Your recent photography products order from {{photography_company_s_name}} are still waiting in your cart.</p>
        <p>Click {{client_gallery_order_page}} to complete your order.</p>
        <p>Your order will be confirmed and sent to production as soon as you complete your purchase.</p>
        <p>If you have any questions please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(7, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email",
        subject_template: "Your Gallery is about to expire! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is about to expire! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(3, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email - follow up 1",
        subject_template: "Don't forget your gallery!",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is about to expire! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 13,
        total_hours: EmailPreset.calculate_total_hours(1, %{calendar: "Day", sign: "-"}),
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Expiring Soon Email - follow up 2",
        subject_template: "Last Day to get your photos and products! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is going to expire tomorrow! Please log into your gallery and make your selections before the gallery expires on {{gallery_expiration_date}}</p>
        <p>You can log into your private gallery to see all of your images {{gallery_link}} here.</p>
        <p>A reminder your photos are password-protected, so you will need to use this password to view: {{password}}</p>
        <p>Any questions, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 14,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Gallery - Gallery Password Changed Email",
        subject_template: "Your password has been successfully changed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your picsello password has been successfully changed. If you did not make this change, please let me know!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 16,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Digital) Order Received",
        subject_template: "Your photos are here! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your image download files are ready:</p>
        <p>1. Click the download link below to download your files now (computer highly recommended for the download) {{download_photos}}</p>
        <p>2. Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible.</p>
        <p>3. Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer!</p>
        <p>If you have any questions, please let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 15,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your products are headed to production now. You can track your order via your {{client_gallery_order_page}}.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 17,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "(BOTH - Digitals and Products) Order Received",
        subject_template: "Your order has been received! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>Congrats! You have successfully ordered photography products from {{gallery_name}} and I can’t wait for you to have your images in your hands!</p>
        <p>Your products are headed to production now. You can track your order via your {{client_gallery_order_page}}.</p>
        <p>Your image download files are ready:</p>
        <p>1. Click the download link below to download your files now (computer highly recommended for the download) {{download_photos}}</p>
        <p>2. Once downloaded, simply unzip the file to access your digital image files to save onto your computer.  We also recommend backing up your files to another location as soon as possible.</p>
        <p>3. Please note that if you save directly to your phone, the resolution will not be of the highest quality so please save to your computer!</p>
        <p>If you have any questions, please let me know.</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 19,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order has shipped email",
        subject_template: "Your products have shipped! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} are now on their way to you! I can’t wait for you to have your images in your hands!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 20,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order is delayed email",
        subject_template: "Your order is delayed | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} have been delayed. I will keep you updated on the ETA. Apologies for the delay it is out of my hands but I am working with the printer to get them to you as soon as we can!</p>
        {{email_signature}}
        """
      },
      %{
        email_automation_pipeline_id: 21,
        total_hours: 0,
        status: "active",
        job_type: "newborn",
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Order has arrived email",
        subject_template: "Your products have arrived! | {{photography_company_s_name}}",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} have arrived! I can't wait for you to see your products. I would love to see them in your home so please send me images when you have them!</p>
        {{email_signature}}
        """
      }
    ]
    |> Enum.each(fn attrs ->
      attrs = Map.merge(attrs, %{inserted_at: now, updated_at: now})
      email_preset = from(ep in EmailPreset, where:
      ep.type == ^attrs.type
      and ep.name == ^attrs.name
      and ep.job_type == ^attrs.job_type
      and ep.email_automation_pipeline_id == ^attrs.email_automation_pipeline_id
      and is_nil(ep.organization_id)
      )
      |> Repo.one()

      if email_preset do
        email_preset |> EmailPreset.default_presets_changeset(attrs) |> Repo.update!()
      else
        attrs |> EmailPreset.default_presets_changeset() |> Repo.insert!()
      end
    end)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
