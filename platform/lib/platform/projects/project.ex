defmodule Platform.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "projects" do
    field :code, :string
    field :name, :string
    field :color, :string, default: "#808080"

    has_many :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :code, :color])
    |> validate_required([:name, :code])
    |> validate_length(:code, min: 1, max: 5)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
  end
end
