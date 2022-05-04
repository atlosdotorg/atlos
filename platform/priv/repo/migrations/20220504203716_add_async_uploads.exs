defmodule Platform.Repo.Migrations.AddAsyncUploads do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add(:upload_type, :string, values: [:user_provided, :direct], default: "user_provided")
      add(:status, :string, values: [:pending, :complete, :error], default: "complete")
    end
  end
end
