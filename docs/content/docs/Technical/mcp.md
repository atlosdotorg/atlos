---
title: MCP
description: Connect AI assistants to Atlos with the Model Context Protocol.
type: docs
sidebar:
  open: true
weight: 2
---

Atlos speaks the [Model Context Protocol](https://modelcontextprotocol.io) (MCP), so AI assistants like Claude can search, read, and — if you allow it — update the incidents in your projects. The MCP server is built into the platform itself, so there is nothing to install.

{{< callout type="info" >}}
If you self-host Atlos, the MCP server is off by default. To turn it on, set the `MCP_ENABLED` environment variable to `true`.
{{< /callout >}}

## Connecting

The MCP endpoint lives at `https://platform.atlos.org/mcp` (or your own host, if you self-host). There are two ways to connect an assistant to it: sign in with your Atlos account, or use a project API token.

### Sign in with your Atlos account

Assistants that support signing in to MCP servers, such as Claude and Cursor, can connect with your Atlos account. Add Atlos as a custom connector or MCP server using the URL `https://platform.atlos.org/mcp`. Your assistant will open an Atlos page in your browser where you:

1. Log in to Atlos, if you aren't already.
2. Choose what the assistant can do: **read only**, **read and comment**, or **read, comment, and edit**.
3. Press **Connect**.

The assistant can then work in all of your projects, including ones you join later.

With Claude Code, for example:

```bash
claude mcp add --transport http atlos https://platform.atlos.org/mcp
```

Then run `/mcp` inside Claude Code and choose Atlos to sign in.

When you connect this way, the assistant acts as you. Its comments and edits appear under your name in the incident's activity feed, and it can never do more than you can: it sees the same incidents you see, and in each project it's limited by your role there. If your role changes, the assistant's access changes with it. Here's the most it can do in a project, depending on your role:

| Your role | What an assistant can do |
|---|---|
| Owner, Manager, Editor | Read, comment, and edit |
| Viewer | Read and comment |
| Data-only viewer | Read, but not the activity feed (just like in Atlos itself) |

{{< callout type="info" >}}
You can see and disconnect your connected assistants at any time from the **Connected Apps** section of your [account settings](https://platform.atlos.org/settings). Disconnecting takes effect immediately. If you're removed from a project, your assistants lose access to it too.
{{< /callout >}}

### Use an API token

You can also connect with the same project-scoped [API tokens]({{< relref "api.md" >}}) as the REST API, passed as a bearer token. This is useful for automated workflows that shouldn't be tied to one person's account. API tokens are only available to project owners. With Claude Code:

```bash
claude mcp add --transport http atlos https://platform.atlos.org/mcp \
  --header "Authorization: Bearer YOUR_API_TOKEN"
```

Actions taken with an API token are attributed to the token, not to a person.

The server uses stateless Streamable HTTP: each request is a single JSON-RPC POST. Server-initiated streams (SSE) are not currently supported.

## Available tools

Which tools an assistant sees depends on the access you gave it (or the API token's permissions). A read-only connection only sees read tools:

| Tool | Requires | What it does |
|---|---|---|
| `list_projects` | Read | The projects the assistant can access, and what it can do in each. |
| `get_project` | Read | Project info, all attribute definitions (IDs, types, options), and the project's members. |
| `search_incidents` | Read | Search and filter incidents; paginated summaries. |
| `get_incident` | Read | Full detail for one incident, by slug, including who is assigned. |
| `get_incident_updates` | Read | The activity feed, including comments, for one incident, one project, or all your projects. Can be limited to comments. |
| `get_source_material` | Read | One piece of source material, with signed artifact download links. |
| `add_comment` | Comment | Post a comment to an incident's feed. |
| `add_source_material` | Editor | Attach a URL as source material, optionally archiving it. |
| `create_incident` | Editor | Create an incident, including custom attribute values. |
| `update_incident_attribute` | Editor | Set one attribute value, with a required explanation. This includes assigning people to an incident by username. |

Every write appears in the incident's activity feed, attributed to you (if you signed in) or to the API token. Attribute updates made over MCP always require an explanation message, so an assistant's actions are auditable. Restricted attributes (like an incident's restrictions) can only be changed by project owners and managers who signed in with their Atlos account, not with an API token. Nothing can be deleted over MCP.

## Safety notes

- **Give assistants only the access they need.** If an assistant only needs to research, choose **read only** when you connect it, or mint a read-only API token. MCP never grants more than you (or the token) already have.
- **Only connect assistants you trust.** When you sign in, the assistant acts as you. Check the name of the app on the Atlos connection page before you press **Connect**, and disconnect apps you no longer use.
- **Treat incident content as untrusted.** Incident descriptions, comments, and source material come from external — sometimes adversarial — sources. A well-behaved assistant should treat that content as data, not instructions; the server's instructions say so, but review your assistant's actions like you would a new teammate's.
- **Sensitive media stays behind links.** Tools return time-limited signed URLs for artifacts rather than file contents, and incident payloads carry their sensitivity flags.
