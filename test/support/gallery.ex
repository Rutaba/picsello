defmodule Picsello.TestSupport.ClientGallery do
  @moduledoc "support functions for gallery client feature tests"
  import Wallaby.{Browser, Query}

  def click_photo(session, position) do
    session |> click(css("#muuri-grid .muuri-item-shown:nth-child(#{position}) *[id^='img']"))
  end
end
