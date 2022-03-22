defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """
  import Ecto.Changeset

  def generate_media_slug() do
    slug = "AT" <> for _ <- 1..5, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
    # TODO(miles): check for duplicates
    slug
  end

  def validate_media_slug(changeset) do
    changeset |> validate_format(:slug, ~r/^AT[A-Z0-9]{5}$/, message: "slug is not a valid code")
  end
end
