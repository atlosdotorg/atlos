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
    |> cast(attrs, [:description])
    |> validate_required([:description])
    |> validate_length(:description, min: 3, max: 100)
    |> put_change(:value, Platform.Utils.generate_secure_code())
  end
end
