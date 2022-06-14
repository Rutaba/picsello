defmodule Picsello.WHCC.EditorTest do
  use Picsello.DataCase, async: true

  import Picsello.Factory
  import Money.Sigils
  import Mox

  setup :verify_on_exit!

  describe "Picsello.WHCC.Editor.Export.Editor" do
    test "serializes to correct json payload" do
      assert %{"orderAttributes" => [123], "editorId" => "foo", "quantity" => 2} ==
               %Picsello.WHCC.Editor.Export.Editor{
                 id: "foo",
                 order_attributes: [123],
                 quantity: 2
               }
               |> Jason.encode!()
               |> Jason.decode!()
    end

    test "skips quantity when nil" do
      assert %{"orderAttributes" => [123], "editorId" => "foo"} ==
               %Picsello.WHCC.Editor.Export.Editor{
                 id: "foo",
                 order_attributes: [123],
                 quantity: nil
               }
               |> Jason.encode!()
               |> Jason.decode!()
    end

    test "associates item with order sequence number" do
      # some data omitted for brevity
      export =
        %{
          "items" => [
            %{
              "editor" => %{
                "id" => "7nAJrNBJxaY6uZFxE"
              },
              "id" => "7nAJrNBJxaY6uZFxE",
              "pricing" => %{
                "basePrice" => 74.25,
                "code" => "USD",
                "markedUpPrice" => 74.25,
                "markupAmount" => 0,
                "markupType" => "PERCENT",
                "quantity" => 1,
                "unitBasePrice" => 74.25
              }
            },
            %{
              "editor" => %{
                "id" => "KpGxg3oHny8B4s3yC"
              },
              "id" => "KpGxg3oHny8B4s3yC",
              "pricing" => %{
                "basePrice" => 51,
                "code" => "USD",
                "markedUpPrice" => 51,
                "markupAmount" => 0,
                "markupType" => "PERCENT",
                "quantity" => 1,
                "unitBasePrice" => 51
              }
            },
            %{
              "editor" => %{
                "id" => "yQ5uuvuNAYo4bnKfn"
              },
              "id" => "yQ5uuvuNAYo4bnKfn",
              "pricing" => %{
                "basePrice" => 5.4,
                "code" => "USD",
                "markedUpPrice" => 5.4,
                "markupAmount" => 0,
                "markupType" => "PERCENT",
                "quantity" => 1,
                "unitBasePrice" => 5.4
              }
            },
            %{
              "editor" => %{
                "id" => "pLyzqg6ESPdjpSZuK"
              },
              "id" => "pLyzqg6ESPdjpSZuK",
              "pricing" => %{
                "basePrice" => 1.5,
                "code" => "USD",
                "markedUpPrice" => 1.5,
                "markupAmount" => 0,
                "markupType" => "PERCENT",
                "quantity" => 1,
                "unitBasePrice" => 1.5
              }
            }
          ],
          "order" => %{
            "Orders" => [
              %{
                "OrderItems" => [
                  %{
                    "EditorId" => "7nAJrNBJxaY6uZFxE"
                  }
                ],
                "SequenceNumber" => 1
              },
              %{
                "OrderItems" => [
                  %{
                    "EditorId" => "yQ5uuvuNAYo4bnKfn"
                  },
                  %{
                    "EditorId" => "pLyzqg6ESPdjpSZuK"
                  }
                ],
                "SequenceNumber" => 2
              },
              %{
                "OrderItems" => [
                  %{
                    "EditorId" => "KpGxg3oHny8B4s3yC"
                  }
                ],
                "SequenceNumber" => 3
              }
            ]
          },
          "pricing" => %{
            "code" => "USD",
            "totalOrderBasePrice" => 132.15,
            "totalOrderMarkedUpPrice" => 132.15
          }
        }
        |> Picsello.WHCC.Editor.Export.new()

      assert [
               %{id: "7nAJrNBJxaY6uZFxE", order_sequence_number: 1, unit_base_price: ~M[7425]USD},
               %{id: "KpGxg3oHny8B4s3yC", order_sequence_number: 3, unit_base_price: ~M[5100]USD},
               %{id: "yQ5uuvuNAYo4bnKfn", order_sequence_number: 2, unit_base_price: ~M[540]USD},
               %{id: "pLyzqg6ESPdjpSZuK", order_sequence_number: 2, unit_base_price: ~M[150]USD}
             ] = export.items
    end
  end

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
