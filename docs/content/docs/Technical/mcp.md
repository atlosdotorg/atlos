---
title: MCP
description: Connect AI assistants to Atlos with the Model Context Protocol.
type: docs
sidebar:
  open: true
weight: 2
---

Atlos speaks the [Model Context Protocol](https://modelcontextprotocol.io) (MCP), so AI assistants like Claude can search, read, and — if you allow it — update the incidents in your project. The MCP server is built into the platform itself: there is nothing to install, and self-hosted deployments serve it automatically.

## Connecting

The MCP endpoint lives at `https://platform.atlos.org/mcp` (or your own host, if you self-host) and authenticates with the same project-scoped [API tokens]({{< relref "api.md" >}}) as the REST API, passed as a bearer token. For example, with Claude Code:

```bash
claude mcp add --transport http atlos https://platform.atlos.org/mcp \
  --header "Authorization: Bearer YOUR_API_TOKEN"
```

Clients that cannot send custom headers can bridge through [`mcp-remote`](https://www.npmjs.com/package/mcp-remote).

The server uses stateless Streamable HTTP: each request is a single JSON-RPC POST. Server-initiated streams (SSE) are not currently supported.

## Available tools

Which tools an assistant sees depends on the token's permissions — a read-only token exposes only read tools, so the token you mint is the ceiling on what an assistant can do:

| Tool | Requires | What it does |
|---|---|---|
| `get_project` | Read | Project info and all attribute definitions (IDs, types, options). |
| `search_incidents` | Read | Search and filter incidents; paginated summaries. |
| `get_incident` | Read | Full detail for one incident, by slug. |
| `get_incident_updates` | Read | The activity feed for one incident or the whole project. |
| `get_source_material` | Read | One piece of source material, with signed artifact download links. |
| `add_comment` | Comment | Post a comment to an incident's feed. |
| `add_source_material` | Editor | Attach a URL as source material, optionally archiving it. |
| `create_incident` | Editor | Create an incident, including custom attribute values. |
| `update_incident_attribute` | Editor | Set one attribute value, with a required explanation. |

Every write is attributed to the API token in the incident's activity feed, and attribute updates made over MCP always require an explanation message, so an assistant's actions are auditable. Restricted attributes (like an incident's restrictions) cannot be changed over MCP, and nothing can be deleted.

## Safety notes

- **Scope tokens deliberately.** If an assistant only needs to research, mint a read-only token. MCP grants no authority beyond the token's permissions.
- **Treat incident content as untrusted.** Incident descriptions, comments, and source material come from external — sometimes adversarial — sources. A well-behaved assistant should treat that content as data, not instructions; the server's instructions say so, but review your assistant's actions like you would a new teammate's.
- **Sensitive media stays behind links.** Tools return time-limited signed URLs for artifacts rather than file contents, and incident payloads carry their sensitivity flags.
