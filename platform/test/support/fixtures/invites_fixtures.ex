defmodule Platform.InvitesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Invites` context.
  """

  @doc """
  Generate a invite.
  """
  def invite_fixture(attrs \\ %{}) do
    {:ok, invite} =
      attrs
      |> Enum.into(%{
        active: true
      })
      |> Platform.Invites.create_invite()

    invite
  end
end
