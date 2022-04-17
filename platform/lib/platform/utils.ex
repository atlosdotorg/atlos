defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """

  def generate_media_slug() do
    slug =
      "ATL-" <>
        for _ <- 1..6, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>

    # TODO(miles): check for duplicates
    slug
  end

  def generate_random_sequence(length) do
    for _ <- 1..length, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
  end

  def make_keys_strings(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  def upload_ugc_file(path) do
    dest = Path.join("priv/static/ugc/", Path.basename(path))
    File.cp!(path, dest)
    {:ok, "/ugc/#{Path.basename(dest)}"}
  end

  def truncate(str, length \\ 30) do
    if String.length(str) > length do
      "#{String.slice(str, 0, length - 3) |> String.trim()}..."
    else
      str
    end
  end
end
