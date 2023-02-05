defmodule Platform.FlexibleJSONType do
  use Ecto.Type

  def type, do: :map

  # Provide custom casting rules.
  def cast(data) do
    case Jason.encode(data) do
      {:ok, _} -> {:ok, data}
      {:error, _} -> :error
    end
  end

  def load(data) do
    {:ok, data}
  end

  def dump(data) do
    case Jason.encode(data) do
      {:ok, _} -> {:ok, data}
      {:error, _} -> :error
    end
  end
end
