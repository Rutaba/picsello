defmodule Picsello.WHCC.ClientTest do
  use ExUnit.Case, async: true

  describe "token" do
    test "fetches token if none exists, and stores for next time" do
      expires = DateTime.utc_now() |> DateTime.truncate(:second)

      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{
          status: 200,
          body: %{"accessToken" => "abc", "expires" => DateTime.to_unix(expires)}
        }
      end)

      assert "abc" ==
               Picsello.WHCC.Client.token(fn f ->
                 {value, %{token: "abc", expires_at: ^expires}} = f.(nil)
                 value
               end)
    end

    test "fetches token if stored token is expired" do
      [old_expires, new_expires] =
        for seconds_offset <- [-10, 10] do
          DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(seconds_offset)
        end

      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{
          status: 200,
          body: %{"accessToken" => "fresh", "expires" => DateTime.to_unix(new_expires)}
        }
      end)

      state = %{token: "expired", expires_at: old_expires}

      assert "fresh" ==
               Picsello.WHCC.Client.token(fn f ->
                 {value, %{token: "fresh", expires_at: ^new_expires}} = f.(state)
                 value
               end)
    end

    test "returns non expired token from store" do
      expires = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(10)

      state = %{token: "stored-token", expires_at: expires}

      assert "stored-token" ==
               Picsello.WHCC.Client.token(fn f ->
                 {value, %{token: "stored-token", expires_at: ^expires}} = f.(state)
                 value
               end)
    end
  end
end
