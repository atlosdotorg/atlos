defmodule PlatformWeb.Errors.NotFound do
  defexception [:message]
end

defmodule PlatformWeb.Errors.Unauthorized do
  defexception [:message]
end

defmodule PlatformWeb.Errors.BadRequest do
  defexception [:message]
end

defimpl Plug.Exception, for: PlatformWeb.Errors.NotFound do
  def status(_exception), do: 404
  def actions(_exception), do: []
end

defimpl Plug.Exception, for: PlatformWeb.Errors.Unauthorized do
  def status(_exception), do: 401
  def actions(_exception), do: []
end

defimpl Plug.Exception, for: PlatformWeb.Errors.BadRequest do
  def status(_exception), do: 400
  def actions(_exception), do: []
end
