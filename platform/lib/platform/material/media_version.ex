defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "media_versions" do
    field(:scoped_id, :integer)

    field(:upload_type, Ecto.Enum, values: [:user_provided, :direct], default: :user_provided)
    field(:source_url, :string)
    field(:metadata, :map, default: %{})

    embeds_many :artifacts, MediaVersionArtifact, primary_key: false do
      field(:id, :binary_id, primary_key: true, autogenerate: true)
      field(:file_location, :string)
      field(:file_hash_sha256, :string)
      field(:file_size, :integer)
      field(:mime_type, :string)
      field(:perceptual_hashes, :map, default: nil)
      field(:title, :string, default: nil)
      belongs_to(:uploading_token, Platform.API.APIToken, type: :binary_id)

      field(:type, Ecto.Enum,
        values: [:pdf, :media, :upload, :viewport, :fullpage, :wacz, :direct_file, :other],
        default: :other
      )

      timestamps()
    end

    field(:status, Ecto.Enum, values: [:pending, :complete, :error], default: :complete)
    field(:visibility, Ecto.Enum, default: :visible, values: [:visible, :hidden, :removed])

    # "Legacy" attributes (when media versions were just single files)
    field(:file_location, :string)
    field(:file_size, :integer)
    field(:mime_type, :string)
    field(:client_name, :string)
    field(:duration_seconds, :integer)

    # Virtual field for when creating new media versions (used by Updates)
    field(:explanation, :string, virtual: true)

    # Computed tsvector field "searchable"; we tell Ecto it's an array of maps so we can use it in queries
    field(:searchable, {:array, :map}, load_in_query: false)

    belongs_to(:media, Media, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [
      :upload_type,
      :status,
      :source_url,
      :media_id,
      :visibility,
      :scoped_id,
      :metadata,
      :explanation
    ])
    |> cast_embed(:artifacts, with: &artifact_changeset/2)
    |> validate_required([
      :status,
      :upload_type,
      :media_id
    ])
    |> validate_length(:explanation,
      max: 2500,
      message: "Explanations cannot exceed 2500 characters."
    )
    # Custom validation: if type is :direct, then :source_url is required (:when does NOT exist)
    |> then(fn changeset ->
      if get_field(changeset, :upload_type) == :direct do
        validate_required(changeset, [:source_url], message: "You must provide a URL to archive.")
      else
        changeset
      end
    end)
    |> unique_constraint([:media_id, :scoped_id], name: "media_versions_scoped_id_index")
  end

  @doc false
  def artifact_changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :id,
      :file_location,
      :file_hash_sha256,
      :file_size,
      :mime_type,
      :perceptual_hashes,
      :type,
      :uploading_token_id,
      :title
    ])
    |> validate_required([
      :file_location,
      :file_hash_sha256,
      :file_size,
      :mime_type,
      :type
    ])
  end
end

defimpl Jason.Encoder, for: Platform.Material.MediaVersion do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :id,
        :inserted_at,
        :scoped_id,
        :source_url,
        :status,
        :updated_at,
        :upload_type,
        :visibility,
        :metadata
      ])
      |> Map.put(:incident_id, value.media_id)
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end)
      |> Map.put(:artifacts, value.artifacts),
      opts
    )
  end
end

defimpl Jason.Encoder, for: Platform.Material.MediaVersion.MediaVersionArtifact do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :id,
        :file_hash_sha256,
        :file_size,
        :mime_type,
        :perceptual_hashes,
        :type
      ])
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end)
      |> Map.put(:access_url, Platform.Material.media_version_artifact_location(value)),
      opts
    )
  end
end
