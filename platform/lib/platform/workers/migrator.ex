defmodule Platform.Workers.Migrator do
  alias Platform.Material
  alias Platform.Updates
  alias Platform.Accounts

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

  def migrate_media(%Platform.Material.Media{} = media) do
    # Migration has three steps:
    # 1. Check if the media has any deprecated attributes set. If so, check whether there are any new project attributes available that are unset, share a name with the deprecated attribute, and are of the same type. If so, set the new attribute to the value of the deprecated attribute.
    # 2. For each of the updates on the project, replace all occurences of the deprecated attribute (in `modified_attribute`, as well as the keys of `old_value` and `new_value`) to the new attribute.
    Logger.info("Migrating #{media.slug}.")

    # Refresh the media, since it was potentially just updated.
    media = Platform.Material.get_media!(media.id)

    set_attributes =
      Material.Attribute.set_for_media(media,
        project: media.project,
        include_deprecated_attributes: true
      )

    for {deprecated_attribute, new_attribute} <- Platform.Utils.migrated_attributes(media) do
      # Refresh the media, since it was likely just updated.
      media = Platform.Material.get_media!(media.id)

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
          {:ok, media} ->
            Logger.info("Migrated #{new_attribute.label} on #{media.slug}.")
            media

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
      if project.attributes == nil or project.attributes == [] do
        Logger.info("Creating custom attributes for #{project.id}.")

        Platform.Projects.change_project(project)
        |> Ecto.Changeset.put_embed(
          :attributes,
          Platform.Projects.ProjectAttribute.default_attributes()
        )
        |> Platform.Repo.update!()
      end
    end
  end

  def verify_integrity() do
    Logger.info("Verifying integrity of all media...")

    for media <- Material.list_media() do
      for {old_attr, new_attr} <- Platform.Utils.migrated_attributes(media) do
        old_value = Material.get_attribute_value(media, old_attr)
        new_value = Material.get_attribute_value(media, new_attr)

        if old_value != nil and old_value != [] and
             Jason.encode(old_value) != Jason.encode(new_value) do
          raise(
            "Integrity check failed for #{media.slug}: #{old_attr.label} (#{old_attr.name}) is #{inspect(old_value)}, but #{new_attr.label} (#{new_attr.name}) is #{inspect(new_value)}."
          )
        end
      end
    end

    Logger.info("Media integrity check passed.")

    Logger.info("Verifying integrity of all updates...")

    for update <- Updates.list_updates() do
      migrated = Platform.Utils.migrated_attributes(update.media)
      old_attr_names = migrated |> Enum.map(fn {old, _new} -> old.name |> to_string() end)

      # Check that the update's modified attribute is not one of the deprecated attributes.
      if Enum.member?(
           old_attr_names,
           update.modified_attribute
         ) do
        raise(
          "Integrity check failed for update #{update.id}: modified attribute #{update.modified_attribute.label} (#{update.modified_attribute.name}) is deprecated."
        )
      end

      for {old_attr, new_attr} <- migrated do
        old_key = Updates.key_for_attribute(old_attr)

        for value <- [update.old_value, update.new_value] do
          with {:ok, map} <- Jason.decode(value), true <- not is_nil(map) do
            if is_map(map) and Map.has_key?(map, old_key) and
                 not (map[old_key] == map[Updates.key_for_attribute(new_attr)]) do
              raise(
                "Integrity check failed for update #{update.id}: #{old_attr.label} (#{old_attr.name}) is #{inspect(map[old_key])}, but #{new_attr.label} (#{new_attr.name}) is #{inspect(map[Updates.key_for_attribute(new_attr)])}."
              )
            end
          end
        end
      end
    end

    Logger.info("Update integrity check passed.")
  end

  def migrate_to_custom_attributes() do
    # Verify that there are no incidents without a project
    if Enum.any?(Platform.Material.list_media(), &is_nil(&1.project_id)) do
      raise(
        "There are media without a project. Please set a project for all media before running the migration."
      )
    end

    create_custom_attributes()
    migrate_all_media()
    verify_integrity()

    Logger.info("Good to go!")
  end

  def add_all_users_to_all_projects() do
    for project <- Platform.Projects.list_projects() do
      for user <- Platform.Accounts.get_all_users() do
        Platform.Projects.create_project_membership(%{
          username: user.username,
          project_id: project.id,
          role: if(Accounts.is_admin(user), do: :owner, else: :editor)
        })
      end
    end
  end
end
