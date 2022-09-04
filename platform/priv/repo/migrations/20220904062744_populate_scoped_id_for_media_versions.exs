defmodule Platform.Repo.Migrations.PopulateScopedIdForMediaVersions do
  use Ecto.Migration
  alias Platform.Material

  def up do
    # There's probably a way to make this more efficient using Repo.update_all — but this is fine. The database at this point is still small.
    versions = Material.list_media_versions()

    versions
    |> Enum.reduce(%{}, fn version, map ->
      existing = Map.get(map, version.media_id, 0)

      {:ok, _} =
        Material.update_media_version(version, %{
          scoped_id: existing + 1
        })

      Map.put(map, version.media_id, existing + 1)
    end)
  end
end
