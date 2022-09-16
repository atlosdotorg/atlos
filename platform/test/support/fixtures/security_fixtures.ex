defmodule Platform.SecurityFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Security` context.
  """

  @doc """
  Generate a security_mode.
  """
  def security_mode_fixture(attrs \\ %{}) do
    {:ok, security_mode} =
      attrs
      |> Enum.into(%{
        description: "some description",
        mode: :normal,
        user_id: Platform.AccountsFixtures.user_fixture(%{roles: [:admin]}).id
      })
      |> Platform.Security.create_security_mode()

    security_mode
  end
end
