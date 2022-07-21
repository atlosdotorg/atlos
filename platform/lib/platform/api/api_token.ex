defmodule Platform.API.APIToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tokens" do
    field :description, :string
    field :value, :string

    timestamps()
  end

  @doc false
  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:value, :description])
    |> validate_required([:value, :description])
  end
end
