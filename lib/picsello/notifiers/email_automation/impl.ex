defmodule Picsello.Notifiers.EmailAutomationNotifier.Impl do
  @moduledoc false
  require Logger

  import Notifiers.Shared
  alias Picsello.{Notifiers.EmailAutomationNotifier, Repo}

  @behaviour EmailAutomationNotifier

  @doc """
  Delivers an automation email for a job.

  This function prepares and delivers an automation email for a job based
  on the provided email preset, job details, email schema, and state. It first
  resolves the email's subject and body templates, and then sends the email to the job's client.

  ## Parameters

      - `email_preset`: The email preset configuration.
      - `job`: The job for which the email is being sent.
      - `schema`: Email schema (specific details required for rendering).
      - `state`: Current state (optional).
      - `helpers`: Helper functions or modules (e.g., PicselloWeb.Helpers).

  ## Returns

      - `{:ok, any}`: Indicates a successful email delivery.
      - `any`: Possible errors or exceptions during email delivery.
  """

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

  @doc """
  Delivers an automation email for a gallery.

  This function prepares and delivers an automation email for a gallery based on
  the provided email preset, gallery details, email schema, and state. It first
  resolves the email's subject and body templates, and then sends the email to the gallery's job client.

  ## Parameters

      - `email_preset`: The email preset configuration.
      - `gallery`: The gallery for which the email is being sent.
      - `schema`: Email schema (specific details required for rendering).
      - `state`: Current state (optional).
      - `helpers`: Helper functions or modules (e.g., PicselloWeb.Helpers).

  ## Returns

      - `{:ok, any}`: Indicates a successful email delivery.
      - `any`: Possible errors or exceptions during email delivery.
  """

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
      %{"to" => gallery.job.client.email},
      gallery.job
    )
  end

  @doc """
  Delivers an automation email for an order.

  This function prepares and delivers an automation email for an order
  based on the provided email preset, order details, email schema, and state.
  It first resolves the email's subject and body templates, and then sends the email
  to the recipient's email address associated with the order's delivery information.

  ## Parameters

      - `email_preset`: The email preset configuration.
      - `order`: The order for which the email is being sent.
      - `schema`: Email schema (specific details required for rendering).
      - `state`: Current state (optional).
      - `helpers`: Helper functions or modules (e.g., PicselloWeb.Helpers).

  ## Returns

      - `{:ok, any}`: Indicates a successful email delivery.
      - `any`: Possible errors or exceptions during email delivery.
  """

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
      case order.delivery_info do
        %{email: email} ->
          deliver_transactional_email(
            %{
              subject: subject,
              body: body
            },
            %{"to" => email},
            order.gallery.job
          )

        _ ->
          Logger.info("No delivery info email address for order #{order.id}")
      end
    end
  end
end
