defmodule Picsello.Repo.Migrations.RemovePaidAtFromBookingProposals do
  use Ecto.Migration

  @old_view """
  create or replace view job_statuses as (
    with proposal_statuses as (
      select
        job_id,
        case
          when deposit_paid_at is not null then 'deposit_paid'
          when questionnaire_answers.id is not null
          and booking_proposals.questionnaire_id is not null then 'answered'
          when signed_at is not null
          and booking_proposals.questionnaire_id is not null then 'signed_with_questionnaire'
          when signed_at is not null then 'signed_without_questionnaire'
          when accepted_at is not null then 'accepted'
          else 'sent'
        end as status,
        coalesce(
          deposit_paid_at,
          questionnaire_answers.inserted_at,
          signed_at,
          accepted_at,
          booking_proposals.inserted_at
        ) as changed_at,
        deposit_paid_at is null as is_lead
      from
        booking_proposals
        left join questionnaire_answers on questionnaire_answers.proposal_id = booking_proposals.id
    )
    select
      id as job_id,
      case
        when archived_at is not null then 'archived'
        when completed_at is not null then 'completed'
        else coalesce(proposal_statuses.status, 'not_sent')
      end as current_status,
      coalesce(proposal_statuses.changed_at, archived_at, completed_at, inserted_at) as changed_at,
      coalesce(proposal_statuses.is_lead, true) as is_lead
    from
      jobs
      left join proposal_statuses on proposal_statuses.job_id = jobs.id
  )
  """

  @new_view """
  create or replace view job_statuses as (
    with proposal_statuses as (
      select
        job_id,
        case
          when questionnaire_answers.id is not null
          and booking_proposals.questionnaire_id is not null then 'answered'
          when signed_at is not null
          and booking_proposals.questionnaire_id is not null then 'signed_with_questionnaire'
          when signed_at is not null then 'signed_without_questionnaire'
          when accepted_at is not null then 'accepted'
          else 'sent'
        end as status,
        coalesce(
          questionnaire_answers.inserted_at,
          signed_at,
          accepted_at,
          booking_proposals.inserted_at
        ) as changed_at
      from
        booking_proposals
        left join questionnaire_answers on questionnaire_answers.proposal_id = booking_proposals.id
    ), payments as (
      select distinct on (job_id) job_id, paid_at
      from payment_schedules
      where paid_at is not null
      order by job_id, paid_at
    )
    select
      id as job_id,
      case
        when archived_at is not null then 'archived'
        when completed_at is not null then 'completed'
        when paid_at is not null then 'deposit_paid'
        else coalesce(proposal_statuses.status, 'not_sent')
      end as current_status,
      coalesce(proposal_statuses.changed_at, archived_at, completed_at, inserted_at) as changed_at,
      paid_at is null as is_lead
    from
      jobs
      left join proposal_statuses on proposal_statuses.job_id = jobs.id
      left join payments on payments.job_id = jobs.id
  )
  """

  def change do
    execute(@new_view, @old_view)

    alter table(:booking_proposals) do
      remove(:deposit_paid_at, :utc_datetime)
      remove(:remainder_paid_at, :utc_datetime)
    end
  end
end
