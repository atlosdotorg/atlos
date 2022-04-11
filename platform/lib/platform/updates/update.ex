defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Accounts.User

  schema "updates" do
    field :explanation, :string
    field :type, Ecto.Enum, values: [:update_attribute, :create, :upload_version, :comment]

    # Used for attribute updates
    field :modified_attribute, Ecto.Enum, nullable: true, values: Attribute.attribute_names()
    # JSON-encoded data
    field :new_value, :string, default: "null"
    # JSON-encoded data
    field :old_value, :string, default: "null"

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
    |> cast(hydrated_attrs, [
      :explanation,
      :old_value,
      :new_value,
      :modified_attribute,
      :type,
      :user_id,
      :media_id,
      :media_version_id
    ])
    |> validate_required([:old_value, :new_value, :type, :user_id, :media_id])
    |> validate_explanation()
    |> validate_inclusion(:modified_attribute, Attribute.attribute_names())
    |> validate_access(user, media)

    # TODO: also validate that if type == :comment, then explanation is not empty
  end

  def validate_access(changeset, %User{} = user, %Media{} = media) do
    if Media.can_user_edit(media, user) do
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
    |> validate_length(:explanation, min: 0, max: 2500)
  end
end
