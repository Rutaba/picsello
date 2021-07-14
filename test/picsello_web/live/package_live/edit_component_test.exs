defmodule PicselloWeb.PackageDetailsComponentTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias PicselloWeb.PackageLive.EditComponent
  alias Picsello.{Package, Repo}
  alias Phoenix.LiveView.Socket

  @endpoint PicselloWeb.Endpoint

  describe "package_template_id" do
    setup :register_and_log_in_user

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
      job = insert(:job, %{user: user, package: %{}})
      {:ok, view, _html} = live(conn, "/jobs/#{job.id}")

      click_edit_package(view)

      [view: view, job: job]
    end

    test "starts with one from package", %{view: view, job: job} do
      %{package: %{package_template_id: template_id}} = job |> Repo.preload(:package)

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

    test "reverts to template id when form is reset", %{view: view, job: job} do
      %{package: %{package_template_id: template_id}} = job |> Repo.preload(:package)

      assert has_element?(view, "option[selected][value=#{template_id}]")

      choose_new_template_package(view)

      assert has_element?(view, "option[selected][value=new]")

      view |> element("button[title='cancel']") |> render_click()
      view |> click_edit_package()

      assert has_element?(view, "option[selected][value=#{template_id}]")
    end
  end

  describe "assign :shoot_count_options" do
    def shoot_count_options(shoot_count) do
      {:ok, %{assigns: %{shoot_count_options: shoot_count_options}}} =
        EditComponent.update([], %Socket{
          assigns: %{
            shoot_count: shoot_count,
            package: %Package{id: 1},
            current_user: insert(:user)
          }
        })

      shoot_count_options
    end

    test "1..5 when or or 1 shoots" do
      for(count <- [0, 1], do: assert([1, 2, 3, 4, 5] = shoot_count_options(count)))
    end

    test "disables numbers less than shoot count" do
      assert [[key: 1, value: 1, disabled: true], 2, 3, 4, 5] = shoot_count_options(2)

      assert [[key: 1, value: 1, disabled: true], [key: 2, value: 2, disabled: true], 3, 4, 5] =
               shoot_count_options(3)
    end
  end
end
