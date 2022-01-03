defmodule PicselloWeb.GalleryLive.MasonryGridTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  test "test_test", state do
    IO.inspect ["###", state]
    assert true == true
  end
end
