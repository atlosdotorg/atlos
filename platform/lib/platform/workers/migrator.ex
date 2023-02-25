defmodule Platform.Workers.Migrator do
  alias Platform.Material
  alias Platform.Updates

  require Logger

  defp update_change_map(
         map,
         %Material.Attribute{} = deprecated_attribute,
         %Material.Attribute{} = new_attribute
       )
       when is_map(map) do
    deprecated_key = Updates.key_for_attribute(deprecated_attribute)
    new_key = Updates.key_for_attribute(new_attribute)

    if Map.has_key?(map, deprecated_key) do
      Map.put(map, new_key, Map.get(map, deprecated_key))
    else
      map
    end
  end

  defp migrate_update(
         %Updates.Update{} = update,
         %Material.Attribute{} = deprecated_attribute,
         %Material.Attribute{} = new_attribute
       ) do
    Logger.info("Migrating update #{update.id}.")

    changeset = Updates.Update.raw_changeset(update, %{})

    changeset =
      if update.modified_attribute == deprecated_attribute.name |> to_string() do
        changeset
        |> Ecto.Changeset.put_change(:modified_attribute, new_attribute.name |> to_string())
      else
        changeset
      end

    changeset =
      with {:ok, value} when is_map(value) <- Jason.decode(update.old_value) do
        Ecto.Changeset.put_change(
          changeset,
          :old_value,
          update_change_map(value, deprecated_attribute, new_attribute) |> Jason.encode!()
        )
      else
        _ -> changeset
      end

    changeset =
      with {:ok, value} when is_map(value) <- Jason.decode(update.new_value) do
        Ecto.Changeset.put_change(
          changeset,
          :new_value,
          update_change_map(value, deprecated_attribute, new_attribute) |> Jason.encode!()
        )
      else
        _ -> changeset
      end

    if changeset.valid? do
      changeset |> Platform.Repo.update!()
      Logger.info("Migrated update #{update.id}.")
    else
      raise("Could not migrate update #{update.id}: #{inspect(changeset.errors)}")
    end
  end

  def migrate_media(%Platform.Material.Media{project: nil} = media) do
    Logger.info("Skipping #{media.slug} because it has no project.")
  end

  def migrate_media(%Platform.Material.Media{} = media) do
    # Migration has three steps:
    # 1. Check if the media has any deprecated attributes set. If so, check whether there are any new project attributes available that are unset, share a name with the deprecated attribute, and are of the same type. If so, set the new attribute to the value of the deprecated attribute.
    # 2. For each of the updates on the project, replace all occurences of the deprecated attribute (in `modified_attribute`, as well as the keys of `old_value` and `new_value`) to the new attribute.
    Logger.info("Migrating #{media.slug}.")

    project_attributes =
      media.project.attributes |> Enum.map(&Platform.Projects.ProjectAttribute.to_attribute(&1))

    deprecated_attributes =
      Material.Attribute.attributes() |> Enum.filter(&(&1.deprecated == true))

    migratable_attribute_pairs =
      deprecated_attributes
      |> Enum.map(fn deprecated_attribute ->
        new_attribute =
          project_attributes
          |> Enum.find(
            &(&1.label == deprecated_attribute.label && &1.type == deprecated_attribute.type)
          )

        if not is_nil(new_attribute) do
          {deprecated_attribute, new_attribute}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    set_attributes =
      Material.Attribute.set_for_media(media,
        project: media.project,
        include_deprecated_attributes: true
      )

    for {deprecated_attribute, new_attribute} <- migratable_attribute_pairs do
      Logger.info(
        "Migrating #{media.slug} from #{deprecated_attribute.name} to #{new_attribute.name}."
      )

      # First, update all updates to point from the old attribute to the new attribute.
      media.updates |> Enum.map(&migrate_update(&1, deprecated_attribute, new_attribute))

      # Second, update the media itself.
      if Enum.member?(set_attributes, deprecated_attribute) do
        # If the deprecated attribute is set, but the new attribute is not, set the new attribute to the value of the deprecated attribute.
        old_value = Material.get_attribute_value(media, deprecated_attribute)

        case Material.update_media_attribute_internal(
               media,
               %{
                 new_attribute
                 | options:
                     (deprecated_attribute.options || []) ++
                       if(is_list(old_value), do: old_value, else: [])
               },
               old_value
             ) do
          {:ok, _} ->
            Logger.info("Migrated #{media.slug}.")

          {:error, changeset} ->
            raise("Could not migrate actual value for #{media.slug}: #{inspect(changeset)}")
        end
      else
        Logger.info(
          "Skipping updating #{deprecated_attribute.label} on #{media.slug} because it is not set."
        )
      end
    end
  end

  # To be called manually when it's time to perform the migration.
  def migrate_all_media() do
    Material.list_media()
    |> Enum.map(&migrate_media/1)
  end

  def create_custom_attributes() do
    for project <- Platform.Projects.list_projects() do
      Platform.Projects.change_project(project)
      |> Ecto.Changeset.put_embed(
        :attributes,
        Platform.Projects.ProjectAttribute.default_attributes()
      )
      |> Platform.Repo.update!()
    end
  end

  def migrate() do
    create_custom_attributes()
    migrate_all_media()
  end
end
