defmodule Picsello.SaveFixtures do
  @moduledoc """
      This can be used to capture responses from a tesla client. ex:
      plug(SaveFixtures, base_path: "test/support/fixtures/whcc")
  """

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, options) do
    result = Tesla.run(env, next)
    save_fixtures(result, options)
    result
  end

  defp save_fixtures({:ok, %{url: url, body: body}}, options) do
    path = url |> URI.parse() |> Map.get(:path)

    options
    |> Keyword.get(:base_path)
    |> Path.join(path |> Path.dirname())
    |> Path.relative_to_cwd()
    |> tap(&File.mkdir_p!/1)
    |> Path.join("#{Path.basename(path)}.json")
    |> File.write!(body)
  end
end
