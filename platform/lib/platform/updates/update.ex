defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias Platform.Material

  schema "updates" do
    field :search_metadata, :string, default: ""
    field :explanation, :string
    field :attachments, {:array, :string}

    field :type, Ecto.Enum,
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

    # Used for attribute updates
    field :modified_attribute, Ecto.Enum,
      nullable: true,
      values:
        Attribute.attribute_names(
          include_renamed_attributes: true,
          include_deprecated_attributes: true
        )

    # JSON-encoded data, used for attribute changes
    field :new_value, :string, default: "null"
    # JSON-encoded data, used for attribute changes
    field :old_value, :string, default: "null"

    field :hidden, :boolean, default: false

    # Used for project changes
    belongs_to :old_project, Platform.Projects.Project, type: :binary_id
    belongs_to :new_project, Platform.Projects.Project, type: :binary_id

    # General association metadata
    belongs_to :user, Platform.Accounts.User
    belongs_to :media, Platform.Material.Media
    belongs_to :media_version, Platform.Material.MediaVersion

    timestamps()
  end

  @doc false
  def changeset(update, attrs, %User{} = user, %Media{} = media) do
    hydrated_attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("media_id", media.id)

    update
    |> raw_changeset(hydrated_attrs)
    |> validate_access(user, media)
  end

  def raw_changeset(update, attrs) do
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
        # TODO: does this being here allow anyone to sneak `:hidden` in when creating an update? Not a big deal, but worth investigating.
        :hidden,
        :old_project_id,
        :new_project_id
      ])
      |> validate_required([:old_value, :new_value, :type, :user_id, :media_id])
      |> validate_explanation()
      |> validate_inclusion(:modified_attribute, Attribute.attribute_names())

    changeset
    |> put_change(
      :search_metadata,
      Accounts.get_user!(get_field(changeset, :user_id)).username <>
        " " <> Material.get_media!(get_field(changeset, :media_id)).slug
    )

    # TODO: also validate that if type == :comment, then explanation is not empty
  end

  def validate_access(changeset, %User{} = user, %Media{} = media) do
    if Media.can_user_edit(media, user) ||
         (get_field(changeset, :type) == :comment and Media.can_user_comment(media, user)) do
      changeset
    else
      changeset
      |> Ecto.Changeset.add_error(
        :media_id,
        "You do not have permission to update or comment on this media"
      )
    end
  end

  def can_user_view(%Platform.Updates.Update{} = update, %User{} = user) do
    cond do
      Accounts.is_privileged(user) -> true
      not Media.can_user_view(update.media, user) -> false
      update.hidden -> false
      true -> true
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
