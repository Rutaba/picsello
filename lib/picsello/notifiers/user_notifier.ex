defmodule Picsello.Notifiers.UserNotifier do
  @moduledoc false
  alias Picsello.{Repo, Accounts.User}
  use Picsello.Notifiers

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    sendgrid_template(:confirmation_instructions_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    sendgrid_template(:password_reset_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    sendgrid_template(:update_email_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver lead converted to job email.
  """
  def deliver_lead_converted_to_job(proposal, helpers) do
    %{job: %{client: %{organization: %{user: user}} = client} = job} =
      proposal |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "#{client.name} just completed their booking proposal!",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>Yay! You have a new job!</p>
      <p>#{client.name} completed their proposal. We have moved them from a lead to a job. Congratulations!</p>
      <p>Click <a href="#{helpers.job_url(job.id)}">here</a> to view and access your job on Picsello.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  @doc """
  Deliver new lead email.
  """
  def deliver_new_lead_email(job, message, helpers) do
    %{client: %{organization: %{user: user}} = client} =
      job |> Repo.preload(client: [organization: [:user]])

    %{
      subject: "You have a new lead from #{client.name}",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>Yay! You have a new lead!</p>
      <p>#{client.name} just submitted a contact form with the following information:</p>
      <p>Email: #{client.email}</p>
      <p>Phone: #{client.phone}</p>
      <p>Job Type: #{helpers.dyn_gettext(job.type)}</p>
      <p>Notes: #{message}</p>
      <p>Click <a href="#{helpers.lead_url(job.id)}">here</a> to view and access your lead on Picsello.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  @doc """
  Deliver new inbound message email.
  """
  def deliver_new_inbound_message_email(client_message, helpers) do
    %{job: %{client: %{organization: %{user: user}} = client} = job} =
      client_message |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "You’ve got mail!",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>You have received a reply from #{client.name}!</p>
      <p>Click <a href="#{helpers.inbox_thread_url(job.id)}">here</a> to view and access your emails on Picsello.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  defp deliver_transactional_email(params, user) do
    sendgrid_template(:generic_transactional_template, params)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end
end
