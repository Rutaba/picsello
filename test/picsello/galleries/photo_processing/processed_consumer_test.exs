defmodule Picsello.Galleries.PhotoProcessing.ProcessedConsumerTest do
  use Picsello.DataCase, async: false

  def test_message(message) do
    Broadway.test_message(
      Picsello.Galleries.PhotoProcessing.ProcessedConsumer,
      Jason.encode!(message),
      metadata: %{sandbox: self()}
    )
  end

  setup do
    "" <> bucket = Keyword.get(Application.get_env(:picsello, :profile_images), :bucket)
    [bucket: bucket]
  end

  describe "profile photo processed" do
    test "updates the profile logo", %{bucket: bucket} do
      Mox.expect(Picsello.PhotoStorageMock, :delete, fn "logo/old.ext", ^bucket -> :ok end)

      version_id = "123"
      path = "bucket/logo/path.ext"

      org =
        insert(:organization,
          profile: %{logo: %{id: version_id, url: "http://example.com/bucket/logo/old.ext"}}
        )

      Picsello.Profiles.subscribe_to_photo_processed(org)

      ref = test_message(%{"path" => path, "metadata" => %{"version-id" => version_id}})

      assert_receive {:ack, ^ref, _, _}

      assert %{profile: %{logo: %{url: url}}} = updated_org = Picsello.Repo.reload!(org)
      assert %{path: "/" <> ^path} = URI.parse(url)

      assert_receive {:image_ready, :logo, ^updated_org}
    end

    test "updates the profile main image", %{bucket: bucket} do
      Mox.expect(Picsello.PhotoStorageMock, :delete, fn "main_image/old.ext", ^bucket -> :ok end)
      version_id = "123"
      path = "bucket/main_image/path.ext"

      org =
        insert(:organization,
          profile: %{
            main_image: %{id: version_id, url: "http://example.com/bucket/main_image/old.ext"}
          }
        )

      Picsello.Profiles.subscribe_to_photo_processed(org)

      ref = test_message(%{"path" => path, "metadata" => %{"version-id" => version_id}})

      assert_receive {:ack, ^ref, _, _}

      assert %{profile: %{main_image: %{url: url}}} = updated_org = Picsello.Repo.reload!(org)
      assert %{path: "/" <> ^path} = URI.parse(url)

      assert_receive {:image_ready, :main_image, ^updated_org}
    end
  end
end
