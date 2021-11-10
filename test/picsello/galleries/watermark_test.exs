defmodule Picsello.Galleries.WatermarkTest do
  use Picsello.DataCase, async: true
  alias Picsello.Galleries.Watermark

  describe "changesets" do
    test "image changeset is valid" do
      changeset = Watermark.image_changeset(%Watermark{}, %{name: "image.png", size: 123_456})
      assert true = changeset.valid?
      assert "image" = changeset.changes[:type]
    end

    test "image changeset is not valid" do
      changeset = Watermark.image_changeset(%Watermark{}, %{})
      assert %{name: ["can't be blank"], size: ["can't be blank"]} = errors_on(changeset)
    end

    test "text changeset is valid" do
      changeset = Watermark.text_changeset(%Watermark{}, %{text: "007 Agency"})
      assert true = changeset.valid?
      assert "text" = changeset.changes[:type]
    end

    test "text changeset is not valid [blank text]" do
      changeset = Watermark.text_changeset(%Watermark{}, %{})
      assert %{text: ["can't be blank"]} = errors_on(changeset)
    end

    test "text changeset is not valid [short text]" do
      changeset = Watermark.text_changeset(%Watermark{}, %{text: ":)"})
      assert %{text: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "text changeset is not valid [long text]" do
      changeset = Watermark.text_changeset(%Watermark{}, %{text: "SuperMegaPhotoAgency:)"})
      assert %{text: ["should be at most 30 character(s)"]} = errors_on(changeset)
    end

    test "switches the type from image to text" do
      watermark = %Watermark{type: "image", name: "image", size: 123_456}
      changeset = Watermark.text_changeset(watermark, %{text: "007 Agency"})
      assert %{text: "007 Agency", name: nil, size: nil, type: "text"} = changeset.changes
    end

    test "switches the type from text to image" do
      watermark = %Watermark{type: "text", text: "007 Agency"}
      changeset = Watermark.image_changeset(watermark, %{name: "image.png", size: 123_456})
      assert %{text: nil, name: "image.png", size: 123_456, type: "image"} = changeset.changes
    end
  end
end
