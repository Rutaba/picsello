defmodule Picsello.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Picsello.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"
  def valid_first_name, do: "Mary"
  def valid_last_name, do: "Jane"
  def valid_business_name, do: "Mary Jane LLC"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      first_name: valid_first_name(),
      last_name: valid_first_name(),
      organization: valid_organization_attributes()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Picsello.Accounts.register_user()

    user
  end

  def valid_organization_attributes do
    %{
      name: valid_business_name()
    }
  end

  def extract_user_token(fun) do
    {:ok, email} = fun.(&"[TOKEN]#{&1}[TOKEN]")

    case email do
      %{private: %{send_grid_template: %{dynamic_template_data: %{"url" => url}}}} -> url
      %{text_body: body} -> body
    end
    |> String.split("[TOKEN]")
    |> Enum.at(1)
  end
end
