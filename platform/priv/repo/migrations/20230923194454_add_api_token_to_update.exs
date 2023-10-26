defmodule Platform.Repo.Migrations.AddApiTokenToUpdate do
  use Ecto.Migration

  def change do
    alter table(:updates) do
      add :api_token_id, references(:api_tokens, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
