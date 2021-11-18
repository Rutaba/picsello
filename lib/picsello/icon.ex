defmodule Picsello.Icon do
  @moduledoc "helpers to ensure validity of icons svg"

  @svg_file "images/icons.svg"
  @external_resource "priv/static/#{@svg_file}"
  @svg_content File.read!("priv/static/#{@svg_file}")

  @names ~r/id="([\w-]+)"/
         |> Regex.scan(@svg_content)
         |> Enum.map(&List.last/1)
         |> tap(&([] = &1 -- Enum.uniq(&1)))

  def names, do: @names

  def public_path(id) when id in @names, do: "/#{@svg_file}##{id}"
end
