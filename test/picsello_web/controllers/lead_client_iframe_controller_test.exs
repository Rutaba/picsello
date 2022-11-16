defmodule PicselloWeb.LeadClientIframeControllerTest do
  use PicselloWeb.ConnCase, async: true

  setup do
    color = Picsello.Profiles.Profile.colors() |> hd

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    %{
      user:
        insert(:user,
          organization: %{
            name: "Mary Jane Photography",
            slug: "mary-jane-photos",
            profile: %{
              color: color,
              job_types: ~w(portrait event)
            }
          }
        )
        |> onboard!
    }
  end

  describe("GET /photographer/embed/:organization_slug") do
    test "photographer doesn't exist or is disabled", %{conn: conn} do
      assert_error_sent :not_found, fn ->
        conn
        |> get(
          Routes.lead_client_iframe_path(
            conn,
            :index,
            "mary"
          )
        )
      end
    end

    test "photographer form renders", %{conn: conn, user: user} do
      assert conn
             |> get(
               Routes.lead_client_iframe_path(
                 conn,
                 :index,
                 user.organization.slug
               )
             )
             |> html_response(200)
             |> String.contains?("Get in touch")
    end
  end

  describe("POST /photographer/embed/:organization_slug") do
    test "user submits empty form", %{conn: conn, user: user} do
      assert conn
             |> post(
               Routes.lead_client_iframe_path(
                 conn,
                 :index,
                 user.organization.slug
               ),
               %{}
             )
             |> get_flash("error")
             |> String.contains?("Form is empty")
    end

    test "user submits incomplete form", %{conn: conn, user: user} do
      assert conn
             |> post(
               Routes.lead_client_iframe_path(
                 conn,
                 :index,
                 user.organization.slug
               ),
               %{
                 "client" => %{
                   "email" => "hey@you.com",
                   "message" => "test",
                   "name" => "Hey You",
                   "phone" => "(000) 000-0000"
                 },
                 "organization_slug" => user.organization.slug
               }
             )
             |> get_flash("error")
             |> String.contains?("Form has errors")
    end

    test "user submits complete form", %{conn: conn, user: user} do
      assert conn
             |> post(
               Routes.lead_client_iframe_path(
                 conn,
                 :index,
                 user.organization.slug
               ),
               %{
                 "client" => %{
                   "email" => "hey@you.com",
                   "message" => "test",
                   "name" => "Hey You",
                   "job_type" => "maternity",
                   "phone" => "(000) 000-0000"
                 }
               }
             )
             |> html_response(200)
             |> String.contains?("Message sent")
    end

    test "user submits form without or an incorrect organization_slug", %{conn: conn} do
      assert_error_sent :not_found, fn ->
        conn
        |> post(
          Routes.lead_client_iframe_path(
            conn,
            :index,
            "test"
          ),
          %{
            "client" => %{
              "email" => "hey@you.com",
              "message" => "test",
              "name" => "Hey You",
              "job_type" => "maternity",
              "phone" => "(000) 000-0000"
            }
          }
        )
      end
    end
  end
end
