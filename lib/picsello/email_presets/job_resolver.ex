defmodule Picsello.EmailPresets.JobResolver do
  @moduledoc "resolves job/lead mustache variables"

  defstruct [:job, :payment_schedule, :helpers]

  def new({%Picsello.Job{} = job}, helpers),
    do: %__MODULE__{
      job: preload_job(job),
      helpers: helpers
    }

  def new({%Picsello.Job{} = job, %Picsello.PaymentSchedule{} = payment_schedule}, helpers),
    do: %__MODULE__{
      job: preload_job(job),
      payment_schedule: payment_schedule,
      helpers: helpers
    }

  defp preload_job(job),
    do:
      Picsello.Repo.preload(job, [
        :booking_proposals,
        :package,
        :shoots,
        client: [organization: :user]
      ])

  defp client(%__MODULE__{job: job}), do: Picsello.Repo.preload(job, :client).client

  defp organization(%__MODULE__{} = resolver),
    do: resolver |> client() |> Picsello.Repo.preload(:organization) |> Map.get(:organization)

  defp photographer(%__MODULE__{} = resolver),
    do: resolver |> organization() |> Picsello.Repo.preload(:user) |> Map.get(:user)

  defp current_proposal(%__MODULE__{job: job}),
    do:
      job
      |> Picsello.Repo.preload(:booking_proposals)
      |> Map.get(:booking_proposals)
      |> Enum.sort_by(& &1.updated_at, DateTime)
      |> List.last()

  defp next_shoot(%__MODULE__{job: job}) do
    job
    |> Picsello.Repo.preload(:shoots)
    |> Map.get(:shoots)
    |> Enum.filter(&(DateTime.compare(&1.starts_at, DateTime.utc_now()) == :gt))
    |> Enum.sort_by(& &1.starts_at, DateTime)
    |> case do
      [next_shoot | _rest] -> next_shoot
      _ -> nil
    end
  end

  defp strftime(%__MODULE__{helpers: helpers} = resolver, date, format) do
    resolver |> photographer() |> Map.get(:time_zone) |> helpers.strftime(date, format)
  end

  defp package(%__MODULE__{job: job}), do: Picsello.Repo.preload(job, :package).package

  defp noop(%__MODULE__{}), do: nil

  defp helpers(%__MODULE__{helpers: helpers}), do: helpers

  def vars,
    do: %{
      "brand_sentence" => &noop/1,
      "client_first_name" => &(&1 |> client() |> Map.get(:name) |> String.split() |> hd),
      "delivery_expectations_sentence" => &noop/1,
      "delivery_time" =>
        &with(
          %{turnaround_weeks: weeks} <- package(&1),
          do:
            helpers(&1).ngettext(
              "one week",
              "%{count} weeks",
              weeks
            )
        ),
      # handled in sendgrid template
      "email_signature" => &noop/1,
      "invoice_amount" => &Picsello.PaymentSchedules.remainder_price(&1.job),
      "invoice_due_date" =>
        &with(
          %DateTime{} = due_on <- Picsello.PaymentSchedules.remainder_due_on(&1.job),
          do:
            strftime(
              &1,
              due_on,
              "%b %-d, %Y"
            )
        ),
      "invoice_link" =>
        &with(
          %Picsello.BookingProposal{id: proposal_id} <- current_proposal(&1),
          do: Picsello.BookingProposal.url(proposal_id)
        ),
      "job_name" => &Picsello.Job.name(&1.job),
      "mini_session_link" => &noop/1,
      "payment_amount" =>
        &case &1.payment_schedule do
          %Picsello.PaymentSchedule{price: price} -> price
          _ -> nil
        end,
      "photographer_cell" =>
        &case photographer(&1) do
          %Picsello.Accounts.User{onboarding: %{phone: "" <> phone}} -> phone
          _ -> nil
        end,
      "photography_company_s_name" => &organization(&1).name,
      "pricing_guide_link" => fn resolver ->
        helpers(resolver).profile_pricing_job_type_url(
          organization(resolver).slug,
          resolver.job.type
        )
      end,
      "remaining_amount" => &Picsello.PaymentSchedules.owed_price(&1.job),
      "review_link" => &noop/1,
      "session_date" =>
        &with(
          %{starts_at: starts_at} <- next_shoot(&1),
          do: strftime(&1, starts_at, "%B %-d, %Y")
        ),
      "session_location" =>
        &with(
          %Picsello.Shoot{} = shoot <- next_shoot(&1),
          do: helpers(&1).shoot_location(shoot)
        ),
      "session_time" =>
        &with(
          %{starts_at: starts_at} <- next_shoot(&1),
          do: strftime(&1, starts_at, "%-I:%M %P")
        ),
      "view_proposal_button" =>
        &with(
          %Picsello.BookingProposal{id: proposal_id} <- current_proposal(&1),
          do: """
          <a style="display:inline-block;background:#1F1C1E;color:#ffffff;font-family:Be Vietnam, Arial;font-size:18px;font-weight:bold;line-height:120%;margin:0;text-decoration:none;text-transform:none;padding:20px 30px;mso-padding-alt:0px;border-radius:12px;"
             target="_blank"
             href="#{Picsello.BookingProposal.url(proposal_id)}">View Proposal</a>
          """
        ),
      "wardrobe_guide_link" => &noop/1,
      "wedding_questionnaire_2_link" => &noop/1
    }
end
