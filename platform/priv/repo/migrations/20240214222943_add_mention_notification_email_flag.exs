defmodule Platform.Repo.Migrations.AddMentionNotificationEmailFlag do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :send_mention_notification_emails, :boolean, default: true
    end
  end
end
