defmodule Picsello.EditLeadContractTest do
  use Picsello.FeatureCase, async: true

  @edit_contract_button button("Edit or Select New")

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

  feature "user saves contract from default template", %{session: session, lead: lead} do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("Picsello Default Contract")
      |> click(@edit_contract_button)
    end)
    |> assert_text("Add Custom Wedding Contract")
    |> assert_has(css("*[role='status']", text: "No edits made"))
    |> assert_selected_option(select("Select a Contract Template"), "Picsello Default Contract")
    |> click(css("div.ql-editor[data-placeholder='Paste contract text here']"))
    |> send_keys(["this is the content of my new contract"])
    |> fill_in(text_field("Contract Name"), with: "My greatest wedding contract")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_flash(:success, text: "New contract added successfully")
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("My greatest wedding contract")
      |> click(@edit_contract_button)
    end)
    |> within_modal(fn modal ->
      modal
      |> assert_text("Add Custom Wedding Contract")
      |> assert_has(css("*[role='status']", text: "No edits made"))
      |> assert_selected_option(
        select("Select a Contract Template"),
        "My greatest wedding contract"
      )
      |> assert_text("this is the content of my new contract")
    end)
  end

  feature "user adds new contract", %{session: session, lead: lead} do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(@edit_contract_button)
    |> assert_text("Add Custom Wedding Contract")
    |> find(select("Select a Contract Template"), &click(&1, option("New Contract")))
    |> fill_in(text_field("Contract Name"), with: "My greatest wedding contract")
    |> click(css("div.ql-editor[data-placeholder='Paste contract text here']"))
    |> send_keys(["this is the content of my new contract"])
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_flash(:success, text: "New contract added successfully")
    |> find(testid("contract"), fn element ->
      element
      |> assert_text("My greatest wedding contract")
      |> click(@edit_contract_button)
    end)
    |> within_modal(fn modal ->
      modal
      |> assert_text("Add Custom Wedding Contract")
      |> assert_selected_option(
        select("Select a Contract Template"),
        "My greatest wedding contract"
      )
      |> assert_text("this is the content of my new contract")
      |> find(
        select("Select a Contract Template"),
        &click(&1, option("Picsello Default Contract"))
      )
      |> assert_text("Retainer and Payment")
    end)
  end

  feature "only displays templates from the same job type", %{
    session: session,
    lead: lead,
    user: user
  } do
    insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")
    insert(:contract_template, user: user, job_type: "family", name: "Contract 2")
    other_user = insert(:user)
    insert(:contract_template, user: other_user, job_type: "wedding", name: "Contract 3")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(@edit_contract_button)
    |> assert_text("Add Custom Wedding Contract")
    |> find(select("Select a Contract Template"), fn element ->
      assert ["New Contract", "Contract 1", "Picsello Default Contract"] =
               element |> all(css("option")) |> Enum.map(&Wallaby.Element.text/1)
    end)
    |> fill_in(text_field("Contract Name"), with: "Contract 1")
    |> assert_text("Contract Name has already been taken")
  end
end