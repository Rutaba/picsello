defmodule Picsello.WHCC.Client.Logger do
  @moduledoc "custom telsa logger for whcc interactions"
  @behaviour Tesla.Middleware

  import Picsello.WHCC, only: [log: 1]

  @impl Tesla.Middleware
  def call(env, next, _opts) do
    env
    |> log_request()
    |> Tesla.run(next)
    |> log_response()
  end

  defp log_request(%{body: "" <> body} = request) do
    log(">>> request body >>>\n#{body}\n")

    request
  end

  defp log_request(request), do: request

  defp log_response({:ok, %{body: "" <> body}} = response) do
    log("<<< response body <<<\n#{body}\n")

    response
  end

  defp log_response(response), do: response
end
