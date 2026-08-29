defmodule PlatformWeb.MCPController do
  @moduledoc """
  MCP (Model Context Protocol) endpoint, speaking JSON-RPC 2.0 over stateless
  Streamable HTTP: every request is a single POST carrying one JSON-RPC
  message, answered with a single JSON response. Sessions and the optional SSE
  stream are not used.

  Authentication and project scoping happen in the router pipeline
  (`PlatformWeb.APIAuth`), identically to the v2 REST API.
  """

  use PlatformWeb, :controller

  require Logger

  alias PlatformWeb.MCP.Server

  def handle(conn, _params) do
    case conn.body_params do
      # A JSON array body (a JSON-RPC batch) is parsed by Phoenix into _json;
      # batching is not part of the current MCP revision.
      %{"_json" => _} ->
        rpc_error(conn, nil, -32600, "batch requests are not supported")

      %{"jsonrpc" => "2.0"} = message ->
        dispatch(conn, message)

      _ ->
        rpc_error(conn, nil, -32600, "expected a JSON-RPC 2.0 message")
    end
  end

  def reject(conn, _params) do
    conn
    |> put_status(:method_not_allowed)
    |> json(%{error: "this MCP endpoint only supports POST requests"})
  end

  # Notifications (no id) are acknowledged with 202 Accepted and no body.
  defp dispatch(conn, %{"method" => "notifications/" <> _} = message) do
    if Map.has_key?(message, "id") do
      rpc_error(conn, message["id"], -32600, "notifications must not have an id")
    else
      send_resp(conn, 202, "")
    end
  end

  defp dispatch(conn, %{"method" => method, "id" => id} = message) do
    params = Map.get(message, "params", %{})

    try do
      handle_method(conn, method, id, params)
    rescue
      error ->
        Logger.error(
          "MCP internal error handling #{method}: #{Exception.format(:error, error, __STACKTRACE__)}"
        )

        rpc_error(conn, id, -32603, "internal error")
    end
  end

  defp dispatch(conn, _message) do
    rpc_error(conn, nil, -32600, "expected a JSON-RPC request with an id, or a notification")
  end

  defp handle_method(conn, "initialize", id, params) do
    rpc_result(conn, id, %{
      protocolVersion: Server.negotiate_protocol_version(params["protocolVersion"]),
      capabilities: %{tools: %{listChanged: false}},
      serverInfo: Server.server_info(),
      instructions: Server.instructions()
    })
  end

  defp handle_method(conn, "ping", id, _params) do
    rpc_result(conn, id, %{})
  end

  defp handle_method(conn, "tools/list", id, _params) do
    tools =
      Server.tools_for_token(conn.assigns.token)
      |> Enum.map(&Server.describe_tool/1)

    rpc_result(conn, id, %{tools: tools})
  end

  defp handle_method(conn, "tools/call", id, params) do
    name = params["name"]
    arguments = Map.get(params, "arguments", %{})

    case Server.call_tool(conn.assigns.token, name, arguments) do
      {:ok, payload} ->
        rpc_result(conn, id, %{
          content: [%{type: "text", text: Jason.encode!(payload)}],
          structuredContent: payload,
          isError: false
        })

      {:tool_error, message} ->
        message = if is_binary(message), do: message, else: Jason.encode!(message)

        rpc_result(conn, id, %{
          content: [%{type: "text", text: message}],
          isError: true
        })

      {:unknown_tool, name} ->
        rpc_error(conn, id, -32602, "unknown or unauthorized tool: #{name}")
    end
  end

  defp handle_method(conn, method, id, _params) do
    rpc_error(conn, id, -32601, "method not found: #{method}")
  end

  defp rpc_result(conn, id, result) do
    json(conn, %{jsonrpc: "2.0", id: id, result: result})
  end

  defp rpc_error(conn, id, code, message) do
    json(conn, %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}})
  end
end
