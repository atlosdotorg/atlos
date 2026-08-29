defmodule PlatformWeb.MCP.Cursor do
  @moduledoc """
  Opaque pagination cursors for MCP tools.

  Uses the same scheme as the v2 API: the underlying Quarto cursor is signed
  with the API token's value as the salt, so cursors are not portable across
  tokens and expire after 24 hours.
  """

  @max_age 86400

  def sign(nil, _api_token_value), do: nil

  def sign(value, api_token_value) do
    Phoenix.Token.sign(PlatformWeb.Endpoint, api_token_value, Jason.encode!(value))
  end

  def extract(nil, _api_token_value), do: {:ok, nil}

  def extract(value, api_token_value) do
    with {:ok, encoded_value} <-
           Phoenix.Token.verify(PlatformWeb.Endpoint, api_token_value, value, max_age: @max_age),
         {:ok, decoded_value} <- Jason.decode(encoded_value) do
      {:ok, decoded_value}
    else
      _ -> {:error, "invalid or expired cursor; restart pagination from the beginning"}
    end
  end
end
