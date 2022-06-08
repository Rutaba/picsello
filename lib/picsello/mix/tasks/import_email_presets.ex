defmodule Mix.Tasks.ImportEmailPresets do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, EmailPreset}

  @shortdoc "import email presets"
  def run(_) do
    load_app()

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    [
      %{
        type: "gallery",
        state: "gallery_send_link",
        position: 0,
        name: "Send gallery link",
        subject_template: "Your Gallery is ready!",
        body_template: """
        <p>Hello {{client_first_name}},</p>
        <p>Your gallery is ready!</p>
        <p>Your photos are password-protected, so you will need to use this password to view: <b>{{password}}</b></p>
        <p>You can log into your private gallery to see all of your images at <a href="{{gallery_link}}">{{gallery_link}}</a>.{{#gallery_expiration_date}} Your gallery expires on {{gallery_expiration_date}}, please make your selections before then.{{/gallery_expiration_date}}</p>
        <p>It’s been a delight working with you and I can’t wait to hear what you think!</p>
        """
      },
      %{
        type: "gallery",
        state: "gallery_shipping_to_client",
        position: 0,
        name: "Your order has shipped - client",
        subject_template: "Your order from {{photography_company_s_name}} has shipped!",
        body_template: """
        <p>Hello {{order_first_name}},</p>
        <p>The photography products you ordered from {{photography_company_s_name}} are now on their way to you!</p>
        <p>We can’t wait for you to have your images in your hands!</p>
        """
      },
      %{
        type: "gallery",
        state: "gallery_shipping_to_photographer",
        position: 0,
        name: "Your order has shipped - photographer",
        subject_template: "New shipping info for {{order_first_name}} order.",
        body_template: """
        <p>Hello {{photographer_first_name}},</p>
        <p>Your client {{order_full_name}}’s order has shipped!</p>
        <p>Cheers!</p>
        """
      }
    ]
    |> Enum.each(fn attrs ->
      attrs = Map.merge(attrs, %{inserted_at: now, updated_at: now})
      email_preset = Repo.get_by(EmailPreset, type: attrs.type, state: attrs.state)

      if email_preset do
        email_preset |> EmailPreset.changeset(attrs) |> Repo.update!()
      else
        attrs |> EmailPreset.changeset() |> Repo.insert!()
      end
    end)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
