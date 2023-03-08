defmodule Platform.Cursor.SignedCursor do
  @moduledoc """
  Custom cursor implementation for Quarto. Adds signing/verification to the base64 encoding.
  See also `Quarto.Cursor.Encode` for the protocol used to encode/decode individual
  values.
  """
  alias Quarto.Cursor
  @behaviour Quarto.Cursor

  @impl true
  def decode(cursor, opts \\ [])
  def decode(nil, _opts), do: {:ok, nil}

  def decode(encoded_cursor, _opts) do
    with {:ok, verified_cursor} <-
           Phoenix.Token.verify(PlatformWeb.Endpoint, "pagination cursor", encoded_cursor),
         {:ok, decoded} <- Base.url_decode64(verified_cursor) do
      {:ok,
       decoded
       |> Plug.Crypto.non_executable_binary_to_term([:safe])
       |> Enum.map(&Cursor.Decode.convert/1)}
    else
      :error -> {:error, :base64_decode_error}
    end
  end

  @impl true
  def decode!(encoded_cursor, opts \\ []) do
    case decode(encoded_cursor, opts) do
      {:ok, cursor} -> cursor
      {:error, error} -> raise(ArgumentError, "error decoding cursor (#{error})")
    end
  end

  @impl true
  def encode(values, opts \\ [])

  def encode(values, _opts) when is_list(values) do
    result =
      values
      |> Enum.map(&Cursor.Encode.convert/1)
      |> :erlang.term_to_binary()
      |> Base.url_encode64()
      |> then(&Phoenix.Token.sign(PlatformWeb.Endpoint, "pagination cursor", &1))

    {:ok, result}
  end

  def encode(value, _opts) do
    encode([value])
  end

  @impl true
  def encode!(values, opts \\ []) do
    {:ok, cursor} = encode(values, opts)
    cursor
  end
end
