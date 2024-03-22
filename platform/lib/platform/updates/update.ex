defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.API.APIToken
  alias Platform.API
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias Platform.Material
  alias Platform.Permissions

  @primary_key {:id, :binary_id, autogenerate: true}
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

    # JSON-encoded data, used for attribute changes; ideally these would be :map, but we have some legacy data that is stored as a non-map JSON object (e.g., array, string)
    field(:new_value, :string, default: "null")

    # JSON-encoded data, used for attribute changes; ideally these would be :map, but we have some legacy data that is stored as a non-map JSON object (e.g., array, string)
    field(:old_value, :string, default: "null")

    field(:hidden, :boolean, default: false)

    # General association metadata
    belongs_to(:user, Platform.Accounts.User, type: :binary_id)
    belongs_to(:media, Platform.Material.Media, type: :binary_id)
    belongs_to(:media_version, Platform.Material.MediaVersion, type: :binary_id)
    belongs_to(:api_token, Platform.API.APIToken, type: :binary_id)

    # Computed tsvector field "searchable"; we tell Ecto it's an array of maps so we can use it in queries
    field(:searchable, {:array, :map}, load_in_query: false)

    timestamps()
  end

  @doc false
  def changeset(update, attrs, %Media{} = media, opts \\ []) do
    user = Keyword.get(opts, :user, nil)
    api_token = Keyword.get(opts, :api_token, nil)

    hydrated_attrs =
      attrs
      |> Map.put("user_id", if(is_nil(user), do: nil, else: user.id))
      |> Map.put("api_token_id", if(is_nil(api_token), do: nil, else: api_token.id))
      |> Map.put("media_id", media.id)

    update
    |> raw_changeset(hydrated_attrs, opts)
    |> validate_access(user, media)
    |> validate_access(api_token, media)
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
        :api_token_id
      ])
      |> then(fn cs ->
        if Keyword.get(opts, :cast_sensitive_data, false) do
          cs |> cast(attrs, [:hidden, :inserted_at])
        else
          cs
        end
      end)
      |> validate_required([:old_value, :new_value, :type, :media_id])
      # Ensure either user_id or api_token_id is set
      |> then(fn cs ->
        validate_change(cs, :user_id, fn :user_id, user_id ->
          if is_nil(user_id) and is_nil(get_field(cs, :api_token_id)) do
            [user_id: "Either user_id or api_token_id must be set"]
          else
            []
          end
        end)
      end)
      |> assoc_constraint(:user)
      |> assoc_constraint(:media)
      |> assoc_constraint(:media_version)
      |> assoc_constraint(:api_token)
      |> validate_explanation()

    search_metadata =
      if get_field(changeset, :user_id) do
        Accounts.get_user!(get_field(changeset, :user_id)).username
      else
        ""
      end <>
        " " <>
        if get_field(changeset, :api_token_id) do
          API.get_api_token!(get_field(changeset, :api_token_id)).name
        else
          ""
        end <>
        " " <>
        Material.get_media!(get_field(changeset, :media_id)).slug

    changeset
    |> put_change(
      :search_metadata,
      search_metadata
    )
  end

  def validate_access(changeset, nil, %Media{}) do
    changeset
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

  def validate_access(changeset, %APIToken{} = api_token, %Media{} = media) do
    if (get_field(changeset, :type) != :comment and
          Permissions.can_api_token_edit_media?(api_token, media)) ||
         (get_field(changeset, :type) == :comment and
            Permissions.can_api_token_post_comment?(api_token, media)) do
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

defimpl Jason.Encoder, for: Platform.Updates.Update do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :id,
        :type,
        :user,
        :new_value,
        :old_value,
        :inserted_at,
        :media_id,
        :explanation,
        :user_id,
        :api_token_id,
        :media_version_id,
        :modified_attribute
      ])
      |> Enum.into(%{}, fn
        {key, value} when key in [:old_value, :new_value] ->
          case Jason.decode(value) do
            {:ok, v} -> {:new_value, v}
            {:error, _} -> {:new_value, value}
          end

        {key, %Ecto.Association.NotLoaded{}} ->
          {key, nil}

        {key, value} ->
          {key, value}
      end),
      opts
    )
  end
end
