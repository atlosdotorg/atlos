defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias Platform.Material
  alias Platform.Permissions

  @derive {Jason.Encoder, except: [:__meta__, :user, :media, :media_version]}
  schema "updates" do
    field(:search_metadata, :string, default: "")
    field(:explanation, :string)
    field(:attachments, {:array, :string})

    field(:type, Ecto.Enum,
      values: [
        :update_attribute,
        :create,
        :upload_version,
        :comment,
        :delete,
        :undelete,
        :add_project,
        :change_project,
        :remove_project
      ]
    )

    # Used for attribute updates.
    field(:modified_attribute, :string)

    # JSON-encoded data, used for attribute changes; ideally these would be :map
    field(:new_value, :string, default: "null")
    # JSON-encoded data, used for attribute changes; ideally these would be :map
    field(:old_value, :string, default: "null")

    field(:hidden, :boolean, default: false)

    # Used for project changes
    belongs_to(:old_project, Platform.Projects.Project, type: :binary_id)
    belongs_to(:new_project, Platform.Projects.Project, type: :binary_id)

    # General association metadata
    belongs_to(:user, Platform.Accounts.User, type: :binary_id)
    belongs_to(:media, Platform.Material.Media, type: :binary_id)
    belongs_to(:media_version, Platform.Material.MediaVersion)

    timestamps()
  end

  @doc false
  def changeset(update, attrs, %User{} = user, %Media{} = media, opts \\ []) do
    hydrated_attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("media_id", media.id)

    update
    |> raw_changeset(hydrated_attrs, opts)
    |> validate_access(user, media)
  end

  def raw_changeset(update, attrs, opts \\ []) do
    changeset =
      update
      |> cast(attrs, [
        :explanation,
        :old_value,
        :new_value,
        :modified_attribute,
        :type,
        :attachments,
        :user_id,
        :media_id,
        :media_version_id,
        :old_project_id,
        :new_project_id
      ])
      |> then(fn cs ->
        if Keyword.get(opts, :cast_sensitive_data, false) do
          cs |> cast(attrs, [:hidden, :inserted_at])
        else
          cs
        end
      end)
      |> validate_required([:old_value, :new_value, :type, :user_id, :media_id])
      |> validate_explanation()

    changeset
    |> put_change(
      :search_metadata,
      Accounts.get_user!(get_field(changeset, :user_id)).username <>
        " " <> Material.get_media!(get_field(changeset, :media_id)).slug
    )

    # TODO: also validate that if type == :comment, then explanation is not empty
  end

  def validate_access(changeset, %User{} = user, %Media{} = media) do
    if Accounts.is_auto_account(user) || Permissions.can_edit_media?(user, media) ||
         (get_field(changeset, :type) == :comment and
            Permissions.can_comment_on_media?(user, media)) do
      changeset
    else
      changeset
      |> Ecto.Changeset.add_error(
        :media_id,
        "You do not have permission to update or comment on this media"
      )
    end
  end

  def validate_explanation(update) do
    update
    # Also validated in attribute.ex
    |> validate_length(:explanation,
      max: 2500,
      message: "Updates cannot exceed 2500 characters."
    )
  end
end
