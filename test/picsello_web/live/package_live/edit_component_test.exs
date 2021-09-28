defmodule PicselloWeb.PackageLiveEditComponentTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias PicselloWeb.PackageLive.EditComponent
  alias Picsello.Repo

  @endpoint PicselloWeb.Endpoint

  setup :register_and_log_in_user

  setup do
    Mox.stub_with(Picsello.MockPayments, Picsello.StripePayments)
    :ok
  end

  describe "package_template_id" do
    def click_edit_package(view),
      do: view |> element("button[title$='Edit package']") |> render_click()

    def choose_new_template_package(view),
      do:
        view
        |> element("form")
        |> render_change(%{
          _target: ["package", "package_template_id"],
          package: %{package_template_id: "new"}
        })

    setup %{user: user, conn: conn} do
      lead = insert(:lead, %{user: user, package: %{}})
      {:ok, view, _html} = live(conn, "/leads/#{lead.id}")

      click_edit_package(view)

      [parent_view: view, view: view |> find_live_child("live_modal"), lead: lead]
    end

    test "starts with one from package", %{view: view, lead: lead} do
      %{package: %{package_template_id: template_id}} = lead |> Repo.preload(:package)

      assert has_element?(view, "option[selected][value=#{template_id}]")
    end

    test "stays new when changed to new", %{view: view} do
      choose_new_template_package(view)

      assert has_element?(view, "option[selected][value=new]")

      view
      |> element("form")
      |> render_change(%{
        _target: ["package", "name"],
        package: %{name: "whatever"}
      })

      assert has_element?(view, "option[selected][value=new]")
    end

    test "reverts to template id when form is reset", %{
      view: view,
      lead: lead,
      parent_view: parent_view
    } do
      %{package: %{package_template_id: template_id}} = lead |> Repo.preload(:package)

      assert has_element?(view, "option[selected][value=#{template_id}]")

      choose_new_template_package(view)

      assert has_element?(view, "option[selected][value=new]")

      view |> element("button[title='cancel']") |> render_click()

      parent_view |> click_edit_package()

      [selected_value] =
        view
        |> render
        |> Floki.find("select[name*='package_template_id'] option[selected]")
        |> Floki.attribute("value")

      assert selected_value == Integer.to_string(template_id)
    end
  end

  describe "assign :shoot_count_options" do
    def shoot_count_options(user, shoot_count) do
      lead =
        insert(:lead, package: %{}, shoots: for(i <- 0..shoot_count, i > 0, do: %{}))
        |> Repo.preload(:package)

      render_component(EditComponent,
        id: EditComponent,
        job: lead,
        package: lead.package,
        current_user: user,
        inner_block: fn _, _ -> nil end
      )
      |> Floki.parse_document!()
      |> Floki.find("#package_shoot_count option")
      |> Enum.map(fn option ->
        %{
          key: option |> Floki.text() |> String.to_integer(),
          value: option |> Floki.attribute("value") |> hd |> String.to_integer(),
          disabled: !(option |> Floki.attribute("disabled") |> Enum.empty?())
        }
      end)
    end

    test "1..5 when 0 or 1 shoots", %{user: user} do
      for(
        count <- [0, 1],
        do:
          assert(
            [
              %{key: 1, disabled: false},
              %{key: 2, disabled: false},
              %{key: 3, disabled: false},
              %{key: 4, disabled: false},
              %{key: 5, disabled: false}
            ] = shoot_count_options(user, count)
          )
      )
    end

    test "disables numbers less than shoot count", %{user: user} do
      assert [
               %{key: 1, value: 1, disabled: true},
               %{disabled: false},
               %{disabled: false},
               %{disabled: false},
               %{disabled: false}
             ] = shoot_count_options(user, 2)

      assert [
               %{key: 1, value: 1, disabled: true},
               %{key: 2, value: 2, disabled: true},
               %{disabled: false},
               %{disabled: false},
               %{disabled: false}
             ] = shoot_count_options(user, 3)
    end
  end
end
