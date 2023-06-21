defmodule Mix.Tasks.ImportEmailPresets do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, EmailPresets.EmailPreset}

  @shortdoc "import email presets"
  def run(_) do
    load_app()

    insert_emails()
  end

  def insert_emails() do
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
      },
      %{
        type: "gallery",
        state: "proofs_send_link",
        position: 0,
        name: "Share Proofing Album",
        subject_template: "Your Proofing Album is Ready!",
        body_template: """
        <p>Hi {{client_first_name}},</p>
        <p>Your proofs are ready to view! You can view your proofing album here: <a href="{{album_link}}">{{album_link}}</a></p>
        {{#album_password}}<p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>{{/album_password}}
        <p>These photos have not been retouched. To select the photos you’d like to purchase to be fully edited, simply favorite the photo. When you’re done selecting your images, select "Send to Photographer." Then I’ll get these fully edited and sent  over to you.</p>
        """
      },
      %{
        type: "gallery",
        state: "album_send_link",
        position: 0,
        name: "Share Finals Album",
        subject_template: "Your Finals Album is Ready!",
        body_template: """
        <p>Hi {{client_first_name}},</p>
        <p>Your Finals are ready to view! You can view your Finals album here: <a href="{{album_link}}">{{album_link}}</a></p>
        {{#album_password}}<p>Your photos are password-protected, so you will need to use this password to view: <b>{{album_password}}</b></p>{{/album_password}}
        <p>These photos have all been retouched, and you can download them all at the touch of a button.</p>
        """
      }
    ]
    |> Enum.each(fn attrs ->
      attrs = Map.merge(attrs, %{inserted_at: now, updated_at: now})
      email_preset = Repo.get_by(EmailPreset, type: attrs.type, state: attrs.state)

      if email_preset do
        email_preset |> EmailPreset.default_presets_changeset(attrs) |> Repo.update!()
      else
        attrs |> EmailPreset.default_presets_changeset() |> Repo.insert!()
      end
    end)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
