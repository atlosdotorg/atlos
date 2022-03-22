defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """
  import Ecto.Changeset
  alias PlatformWeb.Router.Helpers, as: Routes

  def generate_media_slug() do
    slug =
      "AT" <> for _ <- 1..5, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>

    # TODO(miles): check for duplicates
    slug
  end

  def validate_media_slug(changeset) do
    changeset |> validate_format(:slug, ~r/^AT[A-Z0-9]{5}$/, message: "slug is not a valid code")
  end

  def upload_ugc_file(path, socket) do
    dest = Path.join("priv/static/images/ugc/", Path.basename(path))
    File.cp!(path, dest)
    {:ok, Routes.static_path(socket, "/images/ugc/#{Path.basename(dest)}")}
  end
end
