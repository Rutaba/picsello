defmodule Picsello.EmailPresetTest do
  use Picsello.DataCase, async: true
  alias Picsello.EmailPreset
  import Money.Sigils

  describe "for_job" do
    test "post_shoot" do
      organization = insert(:organization)
      package = insert(:package, organization: organization, shoot_count: 3)
      client = insert(:client, organization: organization)
      lead = insert(:lead, package: package, client: client, type: "wedding")
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(-100))
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(-100))
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(100))
      job = promote_to_job(lead)

      %{id: post_shoot_wedding_id} =
        insert(:email_preset, job_state: :post_shoot, job_type: "wedding")

      insert(:email_preset, job_state: :lead, job_type: "wedding")
      insert(:email_preset, job_state: :job, job_type: "wedding")

      insert(:email_preset, job_state: :post_shoot, job_type: "event")

      assert [%EmailPreset{id: ^post_shoot_wedding_id}] = EmailPreset.for_job(job)
    end
  end

  describe "resolve_variables" do
    def resolve_variables(subject, body, job) do
      EmailPreset.resolve_variables(
        %EmailPreset{
          subject_template: subject,
          body_template: body
        },
        job,
        PicselloWeb.ClientMessageComponent.PresetHelper
      )
    end

    def assert_proposal_link(link, proposal_id) do
      assert ["/", "proposals", token] = link |> URI.parse() |> Map.get(:path) |> Path.split()

      assert {:ok, ^proposal_id} =
               Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: 100)
    end

    test "resolve strings" do
      next_year = Map.get(Date.utc_today(), :year) + 1
      shoot_starts_at = ~U[2022-02-09 17:00:00Z] |> Map.put(:year, next_year)

      organization = insert(:organization, name: "Kloster Oberzell", slug: "kloster-oberzell")

      insert(:user, organization: organization, onboarding: %{phone: "(918) 555-1234"})

      job =
        insert(:lead,
          type: "wedding",
          client: insert(:client, name: "Johann Zahn", organization: organization),
          package: insert(:package, base_price: ~M[2000]USD, turnaround_weeks: 2)
        )
        |> Picsello.Repo.reload!()

      insert(:shoot, starts_at: shoot_starts_at, job: job, location: :studio)

      %{id: proposal_id} = insert(:proposal, job: job)

      due_date = "Feb 09, #{next_year}"

      assert %{
               "brand_sentence" => "",
               "client_first_name" => "Johann",
               "delivery_expectations_sentence" => "",
               "delivery_time" => "2 weeks",
               "email_signature" => "",
               "invoice_amount" => "$20.00",
               "invoice_due_date" => ^due_date,
               "invoice_link" => proposal_link,
               "mini_session_link" => "",
               "photographer_cell" => "(918) 555-1234",
               "photography_company_s_name" => "Kloster Oberzell",
               "pricing_guide_link" => pricing_guide_link,
               "review_link" => "",
               "session_date" => ^due_date,
               "session_location" => "In Studio",
               "session_time" => "5:00 pm"
             } =
               resolve_variables(
                 "hi",
                 """
                 {
                 "brand_sentence": "{{brand_sentence}}",
                 "client_first_name": "{{client_first_name}}",
                 "delivery_expectations_sentence": "{{delivery_expectations_sentence}}",
                 "delivery_time": "{{delivery_time}}",
                 "email_signature": "{{email_signature}}",
                 "invoice_amount": "{{invoice_amount}}",
                 "invoice_due_date": "{{invoice_due_date}}",
                 "invoice_link": "{{invoice_link}}",
                 "mini_session_link": "{{mini_session_link}}",
                 "photographer_cell": "{{photographer_cell}}",
                 "photography_company_s_name": "{{photography_company_s_name}}",
                 "pricing_guide_link": "{{pricing_guide_link}}",
                 "review_link": "{{review_link}}",
                 "scheduling_page_link": "{{scheduling_page_link}}",
                 "session_date": "{{session_date}}",
                 "session_location": "{{session_location}}",
                 "session_time": "{{session_time}}",
                 "wardrobe_guide_link": "{{wardrobe_guide_link}}",
                 "wedding_questionnaire_2_link": "{{wedding_questionnaire_2_link}}"
                 }
                 """,
                 job
               )
               |> Map.get(:body_template)
               |> Jason.decode!()

      assert "/photographer/kloster-oberzell/pricing/wedding" =
               pricing_guide_link |> URI.parse() |> Map.get(:path)

      assert_proposal_link(proposal_link, proposal_id)
    end

    test "resolves html" do
      job = insert(:lead)
      %{id: proposal_id} = insert(:proposal, job: job)

      %{body_template: view_proposal_button} =
        resolve_variables("hi", "{{{view_proposal_button}}}", job)

      proposal_link =
        view_proposal_button
        |> Floki.parse_fragment!()
        |> Floki.attribute("href")
        |> hd

      assert_proposal_link(proposal_link, proposal_id)
    end
  end
end
