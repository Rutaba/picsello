defmodule Picsello.EditLeadContractTest do
  use Picsello.FeatureCase, async: true

  @edit_contract_button button("Edit or Select New", at: 0, count: 2)

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead =
      insert(:lead, %{
        type: "wedding",
        user: user
      })

    [lead: lead]
  end

  feature "user sees message when package is missing", %{
    session: session,
    lead: lead
  } do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("You haven’t selected a package yet.")
    end)
  end

  feature "user saves contract from default template", %{session: session, lead: lead, user: user} do
    insert_package(user, lead)

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("Selected contract: Picsello Default Contract")
      |> click(@edit_contract_button)
    end)
    |> assert_has(css("*[role='status']", text: "No edits made"))
    |> assert_selected_option(select("Select template to reset contract language"), "Picsello Default Contract")
    |> assert_has(css("div.ql-editor[data-placeholder='Paste contract text here']"))
    |> fill_in_quill("this is the content of my new contract")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_flash(:success, text: "New contract added successfully")
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("Selected contract: Picsello Default Contract")
      |> click(@edit_contract_button)
    end)
    |> within_modal(fn modal ->
      modal
      |> assert_has(css("*[role='status']", text: "No edits made"))
      |> assert_selected_option(select("Select template to reset contract language"), "Picsello Default Contract")
      |> assert_text("this is the content of my new contract")
    end)
  end

  feature "user adds new contract and then use it in leads", %{session: session, lead: lead, user: user} do
    insert_package(user, lead)

    session
    |> click(css("#hamburger-menu"))
    |> click(link("Contracts"))
    |> assert_text("Meet Contracts")
    |> click(button("Create contract", count: 2, at: 0))
    |> within_modal(
      &(&1
        |> assert_text("Add Contract")
        |> fill_in(text_field("Name"), with: "My greatest wedding contract")
        |> click(css("label", text: "Wedding"))
        |> find(
          css("div.ql-editor"),
          fn e -> e |> Element.clear() end
        )
        |> scroll_to_bottom()
        |> assert_has(css("button:disabled[type='submit']"))
        |> fill_in_quill("content of my new contract")
        |> wait_for_enabled_submit_button()
        |> click(button("Save")))
    )
    |> assert_flash(:success, text: "Contract saved")

    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("Selected contract: Picsello Default Contract")
      |> click(@edit_contract_button)
    end)
    |> within_modal(fn modal ->
      modal
      |> assert_selected_option(
        select("Select template to reset contract language"),
        "Picsello Default Contract"
      )
      |> find(
        select("Select template to reset contract language"),
        &click(&1, option("My greatest wedding contract"))
      )
      |> assert_text("content of my new contract")
    end)
  end

  feature "user selects different contract without editing it", %{
    session: session,
    user: user,
    lead: lead
  } do
    insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")
    insert_package(user, lead)

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(@edit_contract_button)
    |> find(select("Select template to reset contract language"), fn element ->
      element |> click(option("Contract 1"))
    end)
    |> click(button("Save"))
    |> assert_flash(:success, text: "New contract added successfully")
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("Contract 1")
    end)
  end

  feature "only displays templates from the same job type", %{
    session: session,
    lead: lead,
    user: user
  } do
    insert_package(user, lead)
    insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")
    insert(:contract_template, user: user, job_type: "family", name: "Contract 2")
    other_user = insert(:user)
    insert(:contract_template, user: other_user, job_type: "wedding", name: "Contract 3")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(@edit_contract_button)
    |> find(select("Select template to reset contract language"), fn element ->
      assert ["Contract 1", "Picsello Default Contract"] =
               element |> all(css("option")) |> Enum.map(&Wallaby.Element.text/1)
    end)
  end

  defp insert_package(user, lead) do
    package = insert(:package, user: user)

    lead
    |> Picsello.Job.add_package_changeset(%{package_id: package.id})
    |> Picsello.Repo.update!()
  end
end
