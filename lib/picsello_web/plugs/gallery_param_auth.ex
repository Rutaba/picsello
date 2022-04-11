defmodule PicselloWeb.Plugs.GalleryParamAuth do
  @moduledoc """
  Authenticates via get param (for email links)
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]
  alias Picsello.Galleries

  def init(opts \\ %{}), do: Enum.into(opts, %{})

  def call(%{params: %{"hash" => hash} = params, request_path: request_path} = conn, _opts) do
    case params do
      %{"pw" => "" <> password} ->
        with nil <- get_session(conn, "gallery_session_token"),
             {:ok, token} <- Galleries.build_gallery_session_token(hash, password) do
          put_session(conn, "gallery_session_token", token)
        else
          _ -> conn
        end
        |> redirect(to: request_path)
        |> halt()

      _ ->
        conn
    end
  end
end
