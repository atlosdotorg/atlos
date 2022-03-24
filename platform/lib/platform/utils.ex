defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """

  def generate_media_slug() do
    slug =
      "AT-" <>
        for _ <- 1..5, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>

    # TODO(miles): check for duplicates
    slug
  end

  def generate_random_sequence(length) do
    for _ <- 1..length, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
  end

  def upload_ugc_file(path) do
    dest = Path.join("priv/static/images/ugc/", Path.basename(path))
    File.cp!(path, dest)
    {:ok, "/images/ugc/#{Path.basename(dest)}"}
  end
end
