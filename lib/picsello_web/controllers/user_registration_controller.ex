defmodule PicselloWeb.UserRegistrationController do
  use PicselloWeb, :controller

  alias Picsello.Accounts
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
end
