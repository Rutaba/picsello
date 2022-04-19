defmodule Picsello.WHCC.EditorTest do
  use Picsello.DataCase, async: true

  import Picsello.Factory
  import Mox

  setup :verify_on_exit!

  describe "WHCC editor" do
    @some_size "10x15"
    @some_url "https://some.url.org/"
    @some_pixels 2000

    test "correct creation structure building" do
      %{whcc_id: product_whcc_id} = product = insert(:product)

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
        |> Map.merge(%{watermarked: false, preview_url: "the_preview.jpg"})

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

      assert %{
               "productId" => ^product_whcc_id,
               "selections" => %{"size" => @some_size},
               "redirects" => %{
                 "cancel" => %{"url" => @some_url},
                 "complete" => %{"url" => @some_url},
                 "secondary" => %{"url" => @some_url}
               },
               "photos" => [photo | _]
             } = struct

      assert %{
               "url" => url,
               "printUrl" => print_url,
               "size" => %{"original" => %{"height" => @some_pixels, "width" => @some_pixels}}
             } = photo

      assert is_url(url)
      assert is_url(print_url)
    end
  end

  defp is_url(str), do: Enum.member?(~w(http https), str |> URI.parse() |> Map.get(:scheme))
end
