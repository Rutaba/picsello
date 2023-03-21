defmodule PicselloWeb.UserSessionController do
  use PicselloWeb, :controller

  alias Picsello.Accounts
  alias PicselloWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_resp_cookie("show_admin_banner")
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
