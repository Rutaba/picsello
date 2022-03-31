defmodule Picsello.WHCC.EditorTest do
  use Picsello.DataCase, async: true

  import Picsello.Factory
  import Mox

  describe "WHCC editor" do
    @some_size "10x15"
    @some_url "https://some.url.org/"
    @some_pixels 2000

    test "correct creation structure building" do
      product = insert(:product)

      photo =
        insert(:photo,
          gallery:
            insert(:gallery,
              name: "Test gallery_name",
              password: "12345677",
              job: insert(:lead, user: insert(:user))
            ),
          height: @some_pixels,
          width: @some_pixels
        )

      expect(Picsello.PhotoStorageMock, :path_to_url, 2, fn _ ->
        "https://some.fake.storage.url/"
      end)

      struct =
        Picsello.WHCC.Editor.Params.build(product, photo,
          size: @some_size,
          cancel_url: @some_url,
          complete_url: @some_url,
          secondary_url: @some_url
        )

      assert struct |> get_in(~w(productId)) == product.whcc_id
      assert struct |> get_in(~w(selections size)) == @some_size
      assert struct |> get_in(~w(redirects cancel url)) == @some_url
      assert struct |> get_in(~w(redirects complete url)) == @some_url
      assert struct |> get_in(~w(redirects secondary url)) == @some_url
      assert struct |> get_in(~w(photos)) |> Enum.count() > 0

      photo =
        struct["photos"]
        |> Enum.at(0)

      assert is_map(photo)
      assert photo |> get_in(~w(size original height)) == @some_pixels
      assert photo |> get_in(~w(size original width)) == @some_pixels
      assert photo |> get_in(~w(url)) |> is_url()
      assert photo |> get_in(~w(printUrl)) |> is_url()
    end
  end

  defp is_url("http://" <> _), do: true
  defp is_url("https://" <> _), do: true
  defp is_url(_), do: false
end
