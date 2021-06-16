defmodule Picsello.FeatureCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false
      use Wallaby.Feature
      import Wallaby.Query

      def wait_for_enabled_submit_button(session) do
        session |> assert_has(css("button:not(:disabled)[type='submit']"))
      end
    end
  end
end
