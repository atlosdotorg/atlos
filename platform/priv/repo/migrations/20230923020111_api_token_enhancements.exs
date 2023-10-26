defmodule Platform.Repo.Migrations.ApiTokenEnhancements do
  use Ecto.Migration

  def change do
    alter table(:api_tokens) do
      add :is_active, :boolean, default: true
      add :name, :string, null: false, default: "Unnamed Token"
      add :last_used, :date
      add :is_legacy, :boolean, default: true

      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id)
      add :creator_id, references(:users, on_delete: :delete_all, type: :binary_id)

      add :permissions, {:array, :string}, default: [], null: false
    end

    # Indexes
    create index(:api_tokens, [:project_id])
    create index(:api_tokens, [:creator_id])
  end
end
