defmodule Picsello.Notifiers do
  @moduledoc "shared notifier helpers"

  require Logger
  import Bamboo.{Email, SendGridHelper}

  def sendgrid_template(template_key, dynamic_fields) do
    dynamic_fields
    |> Enum.reduce(
      new_email()
      |> with_template(Application.get_env(:picsello, Picsello.Mailer)[template_key])
      |> with_bypass_list_management(true),
      fn {k, v}, e -> add_dynamic_field(e, k, v) end
    )
  end

  def deliver_later(email) do
    email |> Picsello.Mailer.deliver_later()
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      Logger.error(error)
      {:error, exception}
  end

  def email_signature(organization) do
    Phoenix.View.render_to_string(PicselloWeb.EmailSignatureView, "show.html",
      organization: organization,
      user: organization.user
    )
  end

  defmacro __using__(_) do
    quote do
      import Picsello.Notifiers
      import Bamboo.Email
    end
  end
end
