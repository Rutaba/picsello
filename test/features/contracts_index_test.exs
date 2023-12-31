defmodule Picsello.ContractsIndexTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Contract}

  setup :onboarded
  setup :authenticated

  feature "navigate", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(css("[title='Contracts']"))
    |> assert_text("Meet Contracts")
    |> scroll_to_bottom()
    |> assert_has(testid("contracts-row", count: 1))
    |> assert_has(button("Picsello Default Contract"))
  end

  feature "adds, edits, duplicates, deletes contract", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(css("[title='Contracts']"))
    |> assert_text("Meet Contracts")
    |> click(button("Create contract", count: 2, at: 0))
    |> within_modal(
      &(&1
        |> assert_text("Add Contract")
        |> fill_in(text_field("Name"), with: "Contract 1")
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
    |> scroll_to_bottom()
    |> assert_has(testid("contracts-row", count: 2))
    |> assert_has(button("Contract 1"))
    |> assert_has(button("Picsello Default Contract"))
    |> click(button("Manage", count: 2, at: 1))
    |> click(button("Edit"))
    |> within_modal(
      &(&1
        |> assert_text("Edit Contract")
        |> assert_value(text_field("Name"), "Contract 1")
        |> scroll_to_bottom()
        |> find(
          css("div.ql-editor"),
          fn e -> e |> Element.clear() |> Element.fill_in(with: "the greatest contract ever") end
        )
        |> wait_for_enabled_submit_button()
        |> click(button("Save")))
    )
    |> assert_flash(:success, text: "Contract saved")

    contract =
      Repo.all(Contract) |> Enum.filter(fn c -> c.name == "Contract 1" end) |> List.first()

    assert %Contract{
             name: "Contract 1",
             job_type: "wedding",
             content: "<p>the greatest contract ever</p>"
           } = contract

    session
    |> click(css("#hamburger-menu"))
    |> click(css("a", text: "Contracts", count: 2, at: 0))
    |> assert_text("Meet Contracts")
    |> scroll_to_bottom()
    |> assert_has(testid("contracts-row", count: 2))
    |> click(button("Manage", count: 2, at: 0))
    |> click(button("Duplicate", count: 2, at: 0))
    |> within_modal(
      &(&1
        |> assert_text("Edit Contract")
        |> fill_in(text_field("Name"), with: "Duplicate Contract")
        |> click(css("label", text: "Global"))
        |> wait_for_enabled_submit_button()
        |> click(button("Save")))
    )
    |> assert_flash(:success, text: "Contract saved")
    |> assert_has(testid("contracts-row", count: 3))
    |> assert_has(button("Duplicate Contract"))
    |> assert_has(button("Contract 1"))
    |> assert_has(button("Picsello Default Contract"))

    contract =
      Repo.all(Contract)
      |> Enum.filter(fn c -> c.name == "Duplicate Contract" end)
      |> List.first()

    assert %Contract{
             name: "Duplicate Contract",
             job_type: "global",
             content: "<p>the greatest contract ever</p>"
           } = contract

    session
    |> click(css("#hamburger-menu"))
    |> click(css("a", text: "Contracts", count: 2, at: 0))
    |> assert_text("Meet Contracts")
    |> scroll_to_bottom()
    |> assert_has(testid("contracts-row", count: 3))
    |> click(button("Actions", count: 3, at: 1))
    |> click(button("Archive"))
    |> click(button("Yes, archive"))
    |> assert_flash(:success, text: "Contract archived")
    |> scroll_to_bottom()
    |> assert_has(button("Duplicate", count: 2, at: 1))
    |> refute_has(testid("archived-badge", count: 1))
    |> resize_window(1280, 1000)
    |> scroll_into_view(testid("filter_and_sort_bar"))
    |> click(css("#status"))
    |> click(button("All"))
    |> assert_has(testid("archived-badge", count: 1))
    |> assert_has(button("Contract 1"))
    |> assert_has(button("Picsello Default Contract"))

    assert 3 = Repo.all(Contract) |> Enum.count()

    session
    |> click(css("#hamburger-menu"))
    |> click(css("a", text: "Contracts", count: 2, at: 0))
    |> assert_text("Meet Contracts")
    |> scroll_to_bottom()
    |> click(css("#status"))
    |> click(button("All"))
    |> assert_has(testid("contracts-row", count: 3))
    |> click(button("Manage", count: 3, at: 2))
    |> refute_has(button("Archive"))
    |> assert_has(button("Edit", count: 1))
    |> assert_has(button("View"))
    |> click(button("View"))
    |> assert_text("View Contract template")
    |> assert_has(testid("view-only"))
    |> assert_value(text_field("Name"), "Picsello Default Contract")
    |> click(button("Close"))
  end
end
