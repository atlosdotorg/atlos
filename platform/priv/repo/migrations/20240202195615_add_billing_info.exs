defmodule Platform.Repo.Migrations.AddBillingInfo do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :billing_customer_id, :string
      add :billing_info, :map, default: %{}
      add :billing_subscriptions, :map, default: %{}
      add :billing_flags, {:array, :string}, default: []
      add :billing_expires_at, :utc_datetime
    end
  end
end
