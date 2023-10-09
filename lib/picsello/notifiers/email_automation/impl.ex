defmodule Picsello.Notifiers.EmailAutomationNotifier.Impl do
  @moduledoc false
  use Picsello.Notifiers

  alias Picsello.{Notifiers.EmailAutomationNotifier, Repo, Utils, Job, ClientMessage, Messages}

  @behaviour EmailAutomationNotifier

  @spec deliver_automation_email_job(map(), map(), tuple(), atom(), any()) :: :ok
  @impl EmailAutomationNotifier
  def deliver_automation_email_job(email_preset, job, schema, _state, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(email_preset, schema, helpers) do
      body = Utils.normalize_body_template(body)

      deliver_transactional_email(
        %{subject: subject, headline: subject, body: body},
        %{"to" => client.email},
        job
      )
    end
  end

  @spec deliver_automation_email_gallery(map(), map(), tuple(), atom(), any()) :: :ok
  @impl EmailAutomationNotifier
  def deliver_automation_email_gallery(email_preset, gallery, schema, _state, helpers) do
    %{body_template: body, subject_template: subject} =
      Picsello.EmailAutomations.resolve_variables(
        email_preset,
        schema,
        helpers
      )

    body = Utils.normalize_body_template(body)

    deliver_transactional_email(
      %{
        subject: subject,
        body: body
      },
      %{"to" => gallery.job.client.email}
    )
  end

  @spec deliver_automation_email_order(map(), map(), tuple(), atom(), any()) :: :ok
  @impl EmailAutomationNotifier
  def deliver_automation_email_order(email_preset, order, _schema, _state, helpers) do
    with %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(
             email_preset,
             {order.gallery, order},
             helpers
           ) do
      body = Utils.normalize_body_template(body)

      deliver_transactional_email(
        %{
          subject: subject,
          body: body
        },
        %{"to" => order.delivery_info.email},
        order.gallery.job
      )
    end
  end

  defp deliver_transactional_email(params, recipients, %Job{} = job) do
    client = job |> Repo.preload(:client) |> Map.get(:client)
    reply_to = Messages.email_address(job)
    deliver_transactional_email(params, recipients, reply_to, client)
  end

  defp deliver_transactional_email(params, recipients, %ClientMessage{} = message) do
    if message.job do
      reply_to = Messages.email_address(message.job)
      deliver_transactional_email(params, recipients, reply_to, message.job.client)
    else
      deliver_transactional_email(params, recipients)
    end
  end

  defp deliver_transactional_email(params, recipients, reply_to, client) do
    client = client |> Repo.preload(organization: [:user])
    %{organization: organization} = client

    params =
      Map.merge(
        %{
          organization_name: organization.name,
          email_signature: email_signature(organization)
        },
        params
      )
      |> Map.merge(logo_url(organization))

    from_display = organization.name

    :client_transactional_template
    |> sendgrid_template(params)
    |> put_header("reply-to", "#{from_display} <#{reply_to}>")
    |> from({from_display, "noreply@picsello.com"})
    |> to(map_recipients(Map.get(recipients, "to")))
    |> cc(map_recipients(Map.get(recipients, "cc")))
    |> bcc(map_recipients(Map.get(recipients, "bcc")))
    |> deliver_later()
  end

  defp deliver_transactional_email(params, recipients) do
    sendgrid_template(:generic_transactional_template, params)
    |> to(map_recipients(Map.get(recipients, "to")))
    |> cc(map_recipients(Map.get(recipients, "cc")))
    |> bcc(map_recipients(Map.get(recipients, "bcc")))
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp logo_url(organization) do
    case Picsello.Profiles.logo_url(organization) do
      nil -> %{organization_name: organization.name}
      url -> %{logo_url: url}
    end
  end

  defp map_recipients(nil), do: nil

  defp map_recipients(recipients) do
    if is_list(recipients) do
      Enum.map(recipients, &{:email, String.trim(&1)})
    else
      String.split(recipients, ";")
      |> Enum.map(&{:email, String.trim(&1)})
    end
  end
end
