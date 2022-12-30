defmodule Platform.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "projects" do
    field :code, :string
    field :name, :string

    has_many :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :code])
    |> validate_required([:name, :code])
  end
end
