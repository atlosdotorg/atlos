defmodule Platform.UpdatesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Updates` context.
  """

  @doc """
  Generate a update.
  """
  def update_fixture(attrs \\ %{}) do
    {:ok, update} =
      attrs
      |> Enum.into(%{
        explanation: "some explanation",
        modified_attribute: "some modified_attribute",
        new_value: "some new_value",
        old_value: "some old_value"
      })
      |> Platform.Updates.create_update()

    update
  end
end
