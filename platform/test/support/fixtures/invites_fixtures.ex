defmodule Platform.InvitesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Invites` context.
  """

  @doc """
  Generate a invite.
  """
  def invite_fixture(attrs \\ %{}) do
    auto_account = Platform.Accounts.get_auto_account()

    {:ok, invite} =
      attrs
      |> Enum.into(%{
        owner_id: auto_account.id,
        expires: NaiveDateTime.utc_now() |> NaiveDateTime.add(99999, :day),
        single_use: false
      })
      |> Platform.Invites.create_invite()

    invite
  end
end
