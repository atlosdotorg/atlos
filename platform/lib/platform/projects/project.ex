defmodule Platform.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "projects" do
    field(:code, :string)
    field(:name, :string)
    field(:description, :string, default: "")
    field(:color, :string, default: "#fb923c")
    field(:active, :boolean, default: true)
    field(:source_material_archival_enabled, :boolean, default: true)

    # Integrations
    field(:should_sync_with_internet_archive, :boolean, default: false)

    embeds_many(:attributes, Platform.Projects.ProjectAttribute, on_replace: :delete)
    embeds_many(:attribute_groups, Platform.Projects.ProjectAttributeGroup, on_replace: :delete)

    has_many(:media, Platform.Material.Media)
    has_many(:memberships, Platform.Projects.ProjectMembership)

    # Computed tsvector field "searchable"; we tell Ecto it's an array of maps so we can use it in queries
    field(:searchable, {:array, :map}, load_in_query: false)

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :code,
      :color,
      :description,
      :source_material_archival_enabled,
      :should_sync_with_internet_archive
    ])
    |> cast_embed(:attributes, required: false, sort_param: :position)
    |> cast_embed(:attribute_groups, required: false, sort_param: :position)
    |> validate_required([:name, :code, :color])
    |> then(fn changeset ->
      changeset
      |> put_change(:code, String.upcase(Ecto.Changeset.get_field(changeset, :code) || ""))
    end)
    |> validate_length(:code, min: 1, max: 5)
    |> validate_format(:code, ~r/^[a-zA-Z0-9]+$/,
      message: "must only contain letters and numbers"
    )
    |> validate_length(:name, min: 1, max: 40)
    |> validate_length(:description, min: 0, max: 1000)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
  end

  @doc false
  def active_changeset(project, attrs) do
    project
    |> changeset(attrs)
    |> cast(attrs, [:active])
  end
end

defimpl Jason.Encoder, for: Platform.Projects.Project do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :name,
        :code,
        :description,
        :color,
        :id,
        :active,
        :attributes
      ])
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end),
      opts
    )
  end
end
