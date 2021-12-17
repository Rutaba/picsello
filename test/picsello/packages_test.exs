defmodule Picsello.PackagesTest do
  use ExUnit.Case, async: true

  alias Picsello.Packages.Download
  import Money.Sigils

  @default_each_price Download.default_each_price()

  describe "Download.from_package" do
    test "new packages charge 50 ea with no credits" do
      assert %{
               each_price: @default_each_price,
               is_enabled: true,
               is_custom_price: false
             } = Download.from_package(%{download_each_price: nil, download_count: nil})
    end

    test "existing package with default price is same" do
      assert %{
               each_price: @default_each_price,
               is_enabled: true,
               is_custom_price: false
             } = Download.from_package(%{download_each_price: ~M[5000]USD, download_count: nil})
    end

    test "existing package with custom price is_custom_price" do
      assert %{
               each_price: ~M[1000]USD,
               is_enabled: true,
               is_custom_price: true
             } = Download.from_package(%{download_each_price: ~M[1000]USD, download_count: nil})
    end

    test "existing package with zero each_price is disabled" do
      assert %{
               count: nil,
               each_price: ~M[0]USD,
               is_enabled: false,
               is_custom_price: false,
               includes_credits: false
             } = Download.from_package(%{download_each_price: ~M[0]USD, download_count: 0})
    end

    test "existing package with credits includes_credits" do
      assert %{
               count: 12,
               includes_credits: true
             } = Download.from_package(%{download_each_price: ~M[0]USD, download_count: 12})
    end
  end

  describe "Download.changeset" do
    test "if includes_credits count must be positive" do
      assert %{errors: [count: {_, validation: :required}]} =
               Download.changeset(%{includes_credits: true})

      assert %{errors: [count: {_, validation}]} =
               Download.changeset(%{includes_credits: true, count: 0})

      assert :number = Keyword.get(validation, :validation)

      assert %{errors: [count: _]} =
               Download.changeset(%Download{count: 0}, %{includes_credits: true})
    end
  end
end
