defmodule Picsello.Utils do
  @moduledoc false
  def render(template, data),
    do: :bbmustache.render(template, data, key_type: :binary, value_serializer: &to_string/1)
end
