defmodule Picsello.Notifiers.EmailAutomationNotifier.Impl do
  @moduledoc false

  import Notifiers.Shared
  alias Picsello.{Notifiers.EmailAutomationNotifier, Repo, Utils}

  @behaviour EmailAutomationNotifier

  @spec deliver_automation_email_job(map(), map(), tuple(), atom(), any()) ::
          {:error, binary() | map()} | {:ok, map()}
  @impl EmailAutomationNotifier
  def deliver_automation_email_job(email_preset, job, schema, _state, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(email_preset, schema, helpers) do
      deliver_transactional_email(
        %{subject: subject, headline: subject, body: body},
        %{"to" => client.email},
        job
      )
    end
  end

  @spec deliver_automation_email_gallery(map(), map(), tuple(), atom(), any()) ::
          {:error, binary() | map()} | {:ok, map()}
  @impl EmailAutomationNotifier
  def deliver_automation_email_gallery(email_preset, gallery, schema, _state, helpers) do
    %{body_template: body, subject_template: subject} =
      Picsello.EmailAutomations.resolve_variables(
        email_preset,
        schema,
        helpers
      )

    deliver_transactional_email(
      %{
        subject: subject,
        body: body
      },
      %{"to" => gallery.job.client.email}
    )
  end

  @spec deliver_automation_email_order(map(), map(), tuple(), atom(), any()) ::
          {:error, binary() | map()} | {:ok, map()}
  @impl EmailAutomationNotifier
  def deliver_automation_email_order(email_preset, order, _schema, _state, helpers) do
    with %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(
             email_preset,
             {order.gallery, order},
             helpers
           ) do
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
end
