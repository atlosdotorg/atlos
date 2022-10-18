defmodule PlatformWeb.Errors.NotFound do
  defexception [:message]
end

defimpl Plug.Exception, for: PlatformWeb.Errors.NotFound do
  def status(_exception), do: 404
  def actions(_exception), do: []
end
