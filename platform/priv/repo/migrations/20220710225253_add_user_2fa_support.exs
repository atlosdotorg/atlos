defmodule Platform.Repo.Migrations.AddUser2faSupport do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :has_mfa, :boolean, default: false
      add :otp_secret, :binary, nullable: true
    end
  end
end
