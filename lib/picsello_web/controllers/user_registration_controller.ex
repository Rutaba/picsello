defmodule PicselloWeb.UserRegistrationController do
  use PicselloWeb, :controller

  alias Picsello.{Accounts, BrandLinks}
  alias PicselloWeb.UserAuth

  def create(%{req_cookies: cookies} = conn, %{"user" => user_params}) do
    case user_params |> Enum.into(Map.take(cookies, ["time_zone"])) |> Accounts.register_user() do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :confirm, &1)
          )

        add_user_to_sendgrid(user)
        add_brand_links(user)

        conn
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp add_user_to_sendgrid(user) do
    %{
      list_ids: SendgridClient.get_all_contact_list_env(),
      contacts: [
        %{
          email: user.email,
          first_name: Accounts.User.first_name(user),
          last_name: Accounts.User.last_name(user),
          custom_fields: %{
            w4_N: user.id,
            w3_T: user.organization.name,
            w1_T: "pre_trial"
          }
        }
      ]
    }
    |> SendgridClient.add_contacts()
  end

  defp add_brand_links(%{organization: %{id: organization_id}}) do
    brand_links = [
      %{
        title: "Website",
        link: nil,
        link_id: "website",
        organization_id: organization_id
      },
      %{
        title: "Instagram",
        link: "https://www.instagram.com/",
        link_id: "instagram",
        organization_id: organization_id
      },
      %{
        title: "Twitter",
        link: "https://www.twitter.com/",
        link_id: "twitter",
        organization_id: organization_id
      },
      %{
        title: "TikTok",
        link: "https://www.tiktok.com/",
        link_id: "tiktok",
        organization_id: organization_id
      },
      %{
        title: "Facebook",
        link: "https://www.facebook.com/",
        link_id: "facebook",
        organization_id: organization_id
      },
      %{
        title: "Google Reviews",
        link: "https://www.google.com/business",
        link_id: "google-business",
        organization_id: organization_id
      },
      %{
        title: "Linkedin",
        link: "https://www.linkedin.com/",
        link_id: "linkedin",
        organization_id: organization_id
      },
      %{
        title: "Pinterest",
        link: "https://www.pinterest.com/",
        link_id: "pinterest",
        organization_id: organization_id
      },
      %{
        title: "Yelp",
        link: "https://www.yelp.com/",
        link_id: "yelp",
        organization_id: organization_id
      },
      %{
        title: "Snapchat",
        link: "https://www.snapchat.com/",
        link_id: "snapchat",
        organization_id: organization_id
      }
    ]

    BrandLinks.upsert_brand_links(brand_links)
  end
end
