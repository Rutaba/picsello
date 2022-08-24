defmodule Picsello.ClientBooksEventTest do
  use Picsello.FeatureCase, async: false
  import Money.Sigils
  require Ecto.Query

  setup do
    Application.put_env(:picsello, :booking_reservation_seconds, 60 * 10)

    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        }
      )
      |> onboard!

    user.organization
    |> Picsello.Organization.assign_stripe_account_changeset("stripe_id")
    |> Picsello.Repo.update!()

    template =
      insert(:package_template,
        user: user,
        job_type: "mini",
        name: "My custom package",
        download_count: 3,
        base_price: ~M[1500]USD
      )

    event =
      insert(:booking_event,
        name: "Event 1",
        package_template_id: template.id,
        duration_minutes: 45,
        location: "studio",
        address: "320 1st St N",
        description: "This is the description",
        dates: [
          %{
            date: ~D[2050-12-10],
            time_blocks: [
              %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]}
            ]
          },
          %{
            date: ~D[2050-12-11],
            time_blocks: [
              %{start_time: ~T[11:00:00], end_time: ~T[13:00:00]},
              %{start_time: ~T[16:00:00], end_time: ~T[17:00:00]}
            ]
          }
        ]
      )

    [
      photographer: user,
      template: template,
      event: event,
      booking_event_url:
        Routes.client_booking_event_path(
          PicselloWeb.Endpoint,
          :show,
          user.organization.slug,
          event.id
        )
    ]
  end

  feature "client books event", %{
    session: session,
    photographer: %{organization_id: organization_id},
    event: %{id: event_id},
    template: %{id: template_id},
    booking_event_url: booking_event_url
  } do
    Picsello.MockPayments
    |> Mox.stub(:retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)
    |> Mox.stub(:create_customer, fn _, _ ->
      {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
    end)
    |> Mox.stub(:create_session, fn _, _ ->
      {:ok,
       %{
         url:
           PicselloWeb.Endpoint.struct_url()
           |> Map.put(:fragment, "stripe-checkout")
           |> URI.to_string(),
         payment_intent: "new_intent_id",
         id: "new_session_id"
       }}
    end)

    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: " ")
    |> fill_in(text_field("Your email"), with: " ")
    |> fill_in(text_field("Your phone number"), with: " ")
    |> assert_text("Your name can't be blank")
    |> assert_text("Your email can't be blank")
    |> assert_text("Your phone number is invalid")
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> assert_text("December 2050")
    |> click(button("previous month"))
    |> assert_text("November 2050")
    |> click(button("next month"))
    |> assert_text("December 2050")
    |> assert_value(css("input:checked[name='booking[date]']", visible: false), "2050-12-10")
    |> assert_inner_text(
      testid("time_picker"),
      "Saturday, December 10 9:00am 10:00am 11:00am 12:00pm"
    )
    |> click(css("#date_picker-wrapper label", text: "11"))
    |> assert_value(css("input:checked[name='booking[date]']", visible: false), "2050-12-11")
    |> assert_inner_text(
      testid("time_picker"),
      "Sunday, December 11 11:00am 12:00pm 4:00pm"
    )
    |> assert_disabled_submit(text: "Next")
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Your booking reservation expires in 9:")
    |> assert_text(
      "Your session will not be considered officially booked until the contract is signed and a retainer is paid"
    )
    |> assert_text("Event 1")
    |> assert_text("3 images include | 45 min session | In Studio")
    |> assert_text("Sunday, December 11 @ 11:00 am")
    |> assert_text("320 1st St N")
    |> click(button("To-Do Review your proposal"))
    |> assert_has(definition("Total", text: "$15.00"))
    |> click(button("Accept Quote"))
    |> click(button("To-Do Read and agree to your contract"))
    |> assert_text("Retainer and Payment")
    |> fill_in(text_field("Type your full legal name"), with: "Chad Smith")
    |> wait_for_enabled_submit_button()
    |> click(button("Accept Contract"))
    |> click(button("To-Do Pay your invoice"))
    |> assert_has(definition("100% retainer due today", text: "$15.00"))
    |> click(button("Pay Invoice"))
    |> assert_url_contains("stripe-checkout")

    assert [
             %{
               id: job_id,
               type: "mini",
               client: %{
                 name: "Chad Smith",
                 email: "chad@example.com",
                 phone: "(987) 123-4567",
                 organization_id: ^organization_id
               },
               package: %{
                 base_price: ~M[1500]USD,
                 download_count: 3,
                 package_template_id: ^template_id,
                 contract: %{
                   name: "Picsello Default Contract"
                 }
               },
               shoots: [
                 %{
                   name: "Event 1",
                   duration_minutes: 45,
                   location: :studio,
                   address: "320 1st St N",
                   starts_at: ~U[2050-12-11 11:00:00Z]
                 }
               ],
               payment_schedules: [
                 %{
                   price: ~M[1500]USD,
                   description: "100% retainer",
                   stripe_payment_intent_id: "new_intent_id",
                   stripe_session_id: "new_session_id"
                 }
               ],
               booking_proposals: [%{}],
               booking_event_id: ^event_id
             }
           ] =
             Picsello.Repo.all(Picsello.Job)
             |> Picsello.Repo.preload([
               :client,
               :payment_schedules,
               :shoots,
               :booking_proposals,
               [package: :contract]
             ])

    assert [%{args: %{"id" => ^job_id}, worker: "Picsello.Workers.ExpireBooking"}] =
             Picsello.Repo.all(Oban.Job)
  end

  feature "client books event and package has contract", %{
    session: session,
    booking_event_url: booking_event_url,
    photographer: photographer,
    template: template
  } do
    contract_template = insert(:contract_template, user: photographer, job_type: "mini")

    insert(:contract,
      package_id: template.id,
      contract_template_id: contract_template.id,
      content: "my custom contract desc"
    )

    Picsello.MockPayments
    |> Mox.stub(:retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)
    |> Mox.stub(:create_customer, fn _, _ ->
      {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
    end)
    |> Mox.stub(:create_session, fn _, _ ->
      {:ok,
       %{
         url:
           PicselloWeb.Endpoint.struct_url()
           |> Map.put(:fragment, "stripe-checkout")
           |> URI.to_string()
       }}
    end)

    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("#date_picker-wrapper label", text: "11"))
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text(
      "Your session will not be considered officially booked until the contract is signed and a retainer is paid"
    )
    |> click(button("To-Do Read and agree to your contract"))
    |> assert_text("my custom contract desc")
  end

  feature "client tries to book unavailable time", %{
    session: session,
    booking_event_url: booking_event_url,
    photographer: photographer
  } do
    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")

    job = insert(:lead, %{user: photographer})

    insert(:shoot,
      job: job,
      starts_at: DateTime.new!(~D[2050-12-10], ~T[11:00:00], photographer.time_zone)
    )

    session
    |> click(button("Next"))
    |> assert_flash(:error, text: "This time is not available anymore")
  end

  feature "client booking expires", %{session: session, booking_event_url: booking_event_url} do
    Application.put_env(:picsello, :booking_reservation_seconds, 1)

    Picsello.MockPayments
    |> Mox.stub(:retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)
    |> Mox.stub(:create_customer, fn _, _ ->
      {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
    end)

    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Your booking reservation expires in 0:")
    |> assert_path(booking_event_url)
    |> assert_text("Your reservation has expired. You'll have to start over.")
  end
end
