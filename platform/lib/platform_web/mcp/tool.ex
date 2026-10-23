defmodule PlatformWeb.MCP.Tool do
  @moduledoc """
  Behaviour for tools exposed by the Atlos MCP endpoint.

  Tools are thin wrappers around the business-logic contexts (`Platform.Material`,
  `Platform.Updates`, `Platform.Projects`); they must not contain business logic
  of their own. Every tool runs in a project-scoped `PlatformWeb.MCP.Context`
  (acting as an API token or as an OAuth-authorized user) and is only listed
  (and callable) when the context carries `required_permission/0`.
  """

  alias PlatformWeb.MCP.Context

  @doc "The tool's name, as exposed over MCP."
  @callback name() :: String.t()

  @doc "A short human-readable name, shown to people in client UIs (e.g. tool permission settings)."
  @callback title() :: String.t()

  @doc "Human-readable description of the tool, shown to models."
  @callback description() :: String.t()

  @doc "JSON Schema describing the tool's arguments."
  @callback input_schema() :: map()

  @doc "The permission required to list and call this tool."
  @callback required_permission() :: :read | :comment | :edit

  @doc "Whether the tool only reads data."
  @callback read_only?() :: boolean()

  @doc """
  Execute the tool. Returns `{:ok, payload}` where the payload is a
  JSON-encodable term, or `{:error, message}` for a tool-level error that is
  reported to the model (as an MCP tool error, not a protocol error).
  """
  @callback call(Context.t(), map()) :: {:ok, term()} | {:error, String.t() | map()}
end
