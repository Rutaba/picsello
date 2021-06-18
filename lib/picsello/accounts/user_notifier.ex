defmodule Picsello.Accounts.UserNotifier do
  @moduledoc false
  import Bamboo.Email
  import Bamboo.SendGridHelper
  alias Picsello.Mailer
  require Logger

  defp deliver(to, body) do
    new_email()
    |> from("noreply@picsello.com")
    |> to(to)
    |> text_body(body)
    |> Mailer.deliver_later()
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    new_email()
    |> from("noreply@picsello.com")
    |> to(user.email)
    |> with_template(Application.get_env(:picsello, Picsello.Mailer)[:password_reset_template])
    |> add_dynamic_field("name", user.first_name)
    |> add_dynamic_field("url", url)
    |> Mailer.deliver_later()
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      Logger.error(error)
      {:error, exception}
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
