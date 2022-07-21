defmodule Platform.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens) do
      add :value, :string
      add :description, :string

      timestamps()
    end
  end
end
