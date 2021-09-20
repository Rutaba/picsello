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

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
