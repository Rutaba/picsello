defmodule PicselloWeb.UserRegistrationController do
  import Picsello.Zapier.User, only: [user_created_webhook: 1]

  use PicselloWeb, :controller

  alias Picsello.{Accounts, OrganizationCard, GlobalSettings}
  alias PicselloWeb.UserAuth

  def create(%{req_cookies: cookies} = conn, %{"user" => user_params}) do
    user_params
    |> Map.put("organization", %{
      organization_cards: OrganizationCard.for_new_changeset(),
      gs_gallery_products: GlobalSettings.gallery_products_params()
    })
    |> Enum.into(Map.take(cookies, ["time_zone"]))
    |> Accounts.register_user()
    |> case do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :confirm, &1)
          )

        add_user_to_external_tools(user)

        conn
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp add_user_to_external_tools(user) do
    %{
      list_ids: SendgridClient.get_all_client_list_env(),
      clients: [
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
    |> SendgridClient.add_clients()

    user_created_webhook(%{
      email: user.email,
      first_name: Accounts.User.first_name(user),
      last_name: Accounts.User.last_name(user)
    })
  end
end
