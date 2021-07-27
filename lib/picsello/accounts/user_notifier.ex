defmodule Picsello.Accounts.UserNotifier do
  @moduledoc false
  import Bamboo.{Email, SendGridHelper}
  alias Picsello.Mailer
  require Logger

  defp deliver_later(email) do
    email |> Mailer.deliver_later()
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      Logger.error(error)
      {:error, exception}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    sendgrid_template(:confirmation_instructions_template, name: user.first_name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    sendgrid_template(:password_reset_template, name: user.first_name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    sendgrid_template(:update_email_template, name: user.first_name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(client, url) do
    sendgrid_template(:booking_proposal_template, name: client.name, url: url)
    |> to(client.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp sendgrid_template(template_key, dynamic_fields) do
    dynamic_fields
    |> Enum.reduce(
      new_email()
      |> with_template(Application.get_env(:picsello, Picsello.Mailer)[template_key]),
      fn {k, v}, e -> add_dynamic_field(e, k, v) end
    )
  end
end
