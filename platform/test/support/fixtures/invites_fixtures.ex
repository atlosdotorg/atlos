defmodule Platform.InvitesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Invites` context.
  """

  @doc """
  Generate a unique invite code.
  """
  def unique_invite_code, do: "some code#{System.unique_integer([:positive])}"

  @doc """
  Generate a invite.
  """
  def invite_fixture(attrs \\ %{}) do
    {:ok, invite} =
      attrs
      |> Enum.into(%{
        active: true,
        code: unique_invite_code()
      })
      |> Platform.Invites.create_invite()

    invite
  end
end
