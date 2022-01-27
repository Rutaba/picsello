defmodule Picsello.Galleries.PhotoProcessing.ProcessedConsumerTest do
  use Picsello.DataCase, async: false

  def test_message(message) do
    Broadway.test_message(
      Picsello.Galleries.PhotoProcessing.ProcessedConsumer,
      Jason.encode!(message)
    )
  end

  describe "profile photo processed" do
    test "updates the profile" do
      version_id = "123"
      path = "bucket/path.ext"

      org =
        insert(:organization,
          profile: %{logo: %{id: version_id, url: "http://example.com/bucket/old.ext"}}
        )

      Picsello.Profiles.subscribe_to_photo_processed(org)

      ref = test_message(%{"path" => path, "metadata" => %{"version-id" => version_id}})

      assert_receive {:ack, ^ref, _, _}

      assert %{profile: %{logo: %{url: url}}} = updated_org = Picsello.Repo.reload!(org)
      assert %{path: "/" <> ^path} = URI.parse(url)

      assert_receive {:image_ready, ^updated_org}
    end
  end
end
