defmodule Picsello.ProposalReminder do
  @moduledoc false
  alias Picsello.{
    BookingProposal,
    Client,
    Job,
    JobStatus,
    Notifiers.ClientNotifier,
    Organization,
    ClientMessage,
    Repo
  }

  import Ecto.Query

  def deliver_all(now \\ DateTime.utc_now()) do
    if automated_emails_enabled?() do
      BookingProposal
      |> next_proposal_info()
      |> Repo.all()
      |> Enum.each(&maybe_send_message(now, &1))
    else
      :ok
    end
  end

  def next_reminder_on(%BookingProposal{id: proposal_id, job_id: job_id}) do
    with true <- automated_emails_enabled?(),
         {^proposal_id, %{total_sent: total_sent, last_sent_at: last_sent_at}} <-
           from(proposal in BookingProposal, where: proposal.job_id == ^job_id)
           |> next_proposal_info()
           |> Repo.one(),
         %{days: days} <- reminder_messages() |> Enum.at(total_sent) do
      add_days(last_sent_at, days)
    end
  end

  defp next_proposal_info(query) do
    from(proposal in query,
      left_join: message in ClientMessage,
      on: proposal.job_id == message.job_id and message.scheduled,
      join: job_status in JobStatus,
      on: job_status.job_id == proposal.job_id,
      group_by: proposal.id,
      where: job_status.is_lead == true and proposal.sent_to_client,
      select:
        {proposal.id,
         %{
           last_sent_at: message.inserted_at |> max() |> coalesce(proposal.inserted_at),
           total_sent: count(message.id)
         }}
    )
  end

  defp maybe_send_message(
         now,
         {proposal_id, %{last_sent_at: last_sent_at, total_sent: total_sent}}
       ) do
    with %{days: days, copy: copy} <- reminder_messages() |> Enum.at(total_sent),
         true <- elapsed?(now, last_sent_at, days),
         {client_name, client_email, organization_name, job_id} <-
           from(proposal in BookingProposal,
             join: job in Job,
             on: job.id == proposal.job_id and is_nil(job.archived_at),
             join: client in Client,
             on: client.id == job.client_id,
             join: organization in Organization,
             on: organization.id == client.organization_id,
             where: proposal.id == ^proposal_id,
             select: {client.name, client.email, organization.name, job.id}
           )
           |> Repo.one() do
      body = EEx.eval_string(copy, organization_name: organization_name, client_name: client_name)

      %{subject: "Proposal reminder", body_text: body}
      |> ClientMessage.create_outbound_changeset()
      |> Ecto.Changeset.put_change(:job_id, job_id)
      |> Ecto.Changeset.put_change(:scheduled, true)
      |> Repo.insert!()
      |> ClientNotifier.deliver_booking_proposal(client_email)
    end
  end

  defp elapsed?(now, last_sent_at, days),
    do: :lt == last_sent_at |> add_days(days) |> DateTime.compare(now)

  defp add_days(%NaiveDateTime{} = date, days),
    do: date |> DateTime.from_naive!("Etc/UTC") |> add_days(days)

  defp add_days(date, days), do: date |> DateTime.add(:timer.hours(days * 24), :millisecond)

  defp reminder_messages,
    do: [
      %{
        days: 3,
        copy: """
        Hi <%= client_name %>,

        I hope your week is going well so far. I know life gets busy, but I wanted to reach out and touch base to see if there are any questions I can answer for you regarding the booking proposal! If you have any questions, just let me know, and I would be happy to answer them.

        Thank you,

        <%= organization_name %>
        """
      },
      %{
        days: 2,
        copy: """
        Hi <%= client_name %>,

        I hope you're doing well! I’m following up on the proposal I sent you a few days ago and want to make sure you are still interested in the shoot. I know life gets busy, but I want to make sure that I hold the date for you! If you have any questions, please let me know, and I would be happy to answer them.

        Thank you,

        <%= organization_name %>
        """
      },
      %{
        days: 1,
        copy: """
        Hi <%= client_name %>,

        I just want to follow up with you one last time regarding filling out the booking proposal to secure your photoshoot. If you’re still interested, please complete the booking proposal as I can’t hold the date without this, so please let me know either way!

        Thank you,

        <%= organization_name %>
        """
      }
    ]

  defp automated_emails_enabled?,
    do:
      Enum.member?(Application.get_env(:picsello, :feature_flags, []), :automated_proposal_emails)
end
