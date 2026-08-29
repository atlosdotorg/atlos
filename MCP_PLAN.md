# Plan: An MCP Server for Atlos

**Status:** Proposal / implementation plan
**Scope:** Let AI agents (Claude, and any MCP-capable client) work with Atlos investigations — search and read incidents, add source material, post comments, and update attributes — through the Model Context Protocol.

---

## 1. Goals and use cases

An Atlos MCP server should let an investigator point an AI assistant at a project and:

- **Triage & search** — "find all unverified incidents near Kharkiv from March", "which incidents have no source material?"
- **Data entry** — "create an incident for this URL and geolocate it", "set the status of CIV-1234 to Ready for Review with an explanation."
- **Review & synthesis** — "summarize the activity feed on this incident", "draft a comment noting the contradiction between these two sources."
- **Bulk assistance** — walk paginated incident lists to tag, deduplicate, or cross-reference.

Non-goals (initially): user-account administration, project/membership management, deletion of any kind, and binary file *download* through MCP (we link to signed artifact URLs instead).

## 2. What already exists (audit of the current surface)

The v2 HTTP API (`PlatformWeb.APIV2Controller`, routed in `platform/lib/platform_web/router.ex`) already covers most of the needed verbs, all scoped to a **project-scoped API token** (`Platform.API.APIToken`, permissions `[:read, :comment, :edit]`, checked by `PlatformWeb.APIAuth` and `Platform.Permissions`):

| Capability | Endpoint / module |
|---|---|
| Search incidents (full `MediaSearch` filter grammar) | `GET /api/v2/incidents` → `Platform.Material.MediaSearch` |
| List/get source material | `GET /api/v2/source_material[/:id]` |
| Create incident (core + custom attributes) | `POST /api/v2/incidents/new` → `Material.create_media_audited/3` |
| Update one attribute | `POST /api/v2/update/:slug/:attribute` → `Material.update_media_attributes_audited/4` |
| Comment | `POST /api/v2/add_comment/:slug` → `Updates.post_comment_from_api_token/3` |
| Activity feed | `GET /api/v2/updates` |
| Add source material by URL (with archival) | `POST /api/v2/source_material/new/:slug` |
| Upload artifact file / set metadata | `POST /api/v2/source_material/upload/:id`, `.../metadata/:id/:namespace` |

Pagination is cursor-based (Quarto + `Platform.Cursor.SignedCursor`), with cursors **signed against the token value and expiring after 24h** — fine for a server that holds the token, not portable otherwise.

**Gaps and rough edges the MCP effort surfaces** (worth fixing regardless of MCP):

1. **No way to list a project's custom-attribute definitions.** `ProjectAttribute`'s `Jason.Encoder` derive omits `id`, and there is no `GET /api/v2/project` endpoint — so an API client cannot discover the UUIDs needed for `POST /update/:slug/:attribute` without scraping `project_attributes` off a sample incident. This is the single most important platform-side addition.
2. **Error model:** nearly every failure returns HTTP 401 with `{"error": ...}` — missing params, not-found, and true auth failures are indistinguishable. Tool feedback to an LLM needs better discrimination.
3. `check_api_token/2` does not check `is_active`, and the plain read endpoints skip `can_api_token_read_updates?`-style checks — an inactive token can still read.
4. `Update`'s JSON encoder overwrites `old_value` with `new_value` (both re-keyed to `:new_value`), losing change history in API output.
5. `POST /source_material/new/:slug` compares `archive == "true"` (string), while docs describe a boolean.
6. Docs say 30 results/page; code hardcodes `limit: 100`.

## 3. Architecture decision

Three shapes were considered:

- **(A) Standalone server wrapping the REST API** (TypeScript/Python, stdio, installed per-user via `npx`/`uvx`).
- **(B) In-app MCP endpoint** — Streamable HTTP served by the Phoenix app itself.
- **(C) Hybrid** — standalone server plus small REST additions.

**Recommendation: (B) — build MCP into the platform as a Streamable HTTP endpoint at `/mcp`.**

Rationale:

- **Zero client install.** Users add `https://platform.atlos.org/mcp` with their existing project API token as a bearer header (Claude Code: `claude mcp add --transport http atlos https://platform.atlos.org/mcp --header "Authorization: Bearer <token>"`; clients without header support can bridge via `mcp-remote`). Self-hosters get MCP for free with their deployment.
- **Reuses everything.** Auth (`PlatformWeb.APIAuth` plugs verbatim), permissions (`Platform.Permissions.can_api_token_*`), search (`MediaSearch`), business logic (`Material`, `Updates`, `Projects`), and the existing `Jason.Encoder` output shapes — no HTTP hop, no drift between MCP and API behavior, and gap #1 disappears because the server can call `Projects.get_project_attributes/1` directly.
- **One deployment, one audit trail.** Writes flow through the same `*_audited` functions, so updates attribute to the API token exactly as today; `Platform.Security` mode and billing gates (`Plan.allowed_api`) apply unchanged.
- **Elixir MCP support exists**: use the `anubis_mcp` (formerly `hermes-mcp`) library, or hand-roll a small Plug — Streamable HTTP in stateless mode is a single JSON-RPC POST endpoint, which sidesteps long-lived-connection concerns (Fly's `hard_limit = 25` per instance) by skipping the optional SSE stream initially.

Option (A) remains a cheap follow-on: a thin npm package that proxies stdio→HTTP for users whose clients can't do remote MCP at all. It should be generated from the same tool definitions, not hand-maintained.

## 4. Tool surface (v1)

All tools operate within the token's project. Exposed tools are filtered by token permissions at `initialize` time: `:read` → read tools only; `:comment` adds `add_comment`; `:edit` adds the write tools. Read tools get `readOnlyHint: true` annotations.

| Tool | Maps to | Notes |
|---|---|---|
| `get_project` | `Projects.get_project/1` + `get_project_attributes/1` | Returns name, code, and **full attribute definitions with IDs, types, and options** — the schema an agent needs before writing. |
| `search_incidents` | `MediaSearch.changeset/1` + `Material.query_media_paginated/2` | Params mirror the web UI grammar: `query`, `status[]`, `tags[]`, `sensitive[]`, `date_min/max`, `geolocation` + radius, `no_media_versions`, `sort`. Returns a page + opaque `cursor`. |
| `get_incident` | `Material.get_full_media_by_slug/1` | By slug (accepts `CODE-SLUG` display form via `find_raw_slug/1`). Includes source material and custom attribute values. |
| `get_incident_updates` | `Updates.query_updates_paginated/2` | Feed for one incident or whole project; comments, attribute changes, authorship. |
| `create_incident` | `Material.create_media_audited/3` | Same key semantics as `POST /incidents/new`: core attrs, custom-attr UUIDs, `urls[]` (auto-archived), `geolocation` as `"lat,lon"`. |
| `update_incident_attribute` | `Material.generate_attribute_change_params/4` → `update_media_attributes_audited/4` | Attribute by core name or custom UUID; requires `message` (explanation) — stricter than the REST API, deliberately, so agent edits are always explained in the feed. |
| `add_comment` | `Updates.post_comment_from_api_token/3` | Max 2500 chars. |
| `add_source_material` | `Material.create_media_version_audited/3` + `archive_media_version/1` | URL + `archive: boolean` (proper boolean). Returns the created version; note archival is async (`status: pending`). |
| `get_source_material` | `Material.get_media_version/1` | Includes artifacts with signed `access_url`s so the agent (or user) can open files. |

Deferred beyond v1: file upload (base64 over MCP is a poor fit; revisit once MCP file/resource upload patterns settle), `set_source_material_metadata`, MCP *resources* for incidents (`atlos://incident/{slug}`), and PubSub-driven change notifications via `Material.pubsub_topic_for_media/1` (needs the SSE half of Streamable HTTP).

Design rules for all tools:

- **Structured, small outputs.** Reuse the existing encoders but trim: no `auto_metadata` blobs, cap `versions` embedded in search results, always include `slug` and web URL (`https://<host>/incidents/<slug>`) so users can jump in.
- **Real errors.** Map changeset errors to MCP tool errors with the field-level messages from `render_changeset_errors/1`; distinguish `not_found` / `unauthorized` / `invalid_params` instead of the API's blanket 401 behavior.
- **Pagination as opaque cursor param**, documented in the tool description ("pass `cursor` from the previous result to continue").

## 5. Implementation phases

### Phase 0 — Platform hardening & prerequisites (small PRs, valuable standalone)

1. Add `GET /api/v2/project` returning project info + attribute definitions **including `id`, `type`, `options`** (fixes gap #1 for REST users too; the MCP `get_project` tool shares its serializer).
2. Fix `Update` encoder `old_value` bug; check `is_active` in `check_api_token/2`; accept boolean `archive`; correct the docs' page-size claim.
3. Decide error-status policy for v2 (introduce 400/403/404 without breaking existing clients — additive, since current clients key off `success`/`error` bodies).

### Phase 1 — MCP endpoint (core deliverable)

1. Add `anubis_mcp` dependency (or a minimal JSON-RPC Plug if we prefer zero deps); mount at `scope "/mcp"` piped through `[:api, :check_api_token, :require_project_scoped_token]` in `router.ex`.
2. Implement the nine v1 tools as thin modules under `platform/lib/platform_web/mcp/`, each delegating to the context functions above — no business logic in the MCP layer.
3. Permission-filtered tool listing + `readOnlyHint` annotations; audit log entries via `Platform.Auditor` for MCP-originated writes (mirroring `:media_created` etc.).
4. Tests: ExUnit coverage per tool (happy path, permission denial, inactive token, changeset errors), plus an integration test speaking JSON-RPC over the endpoint.

### Phase 2 — Distribution & docs

1. Docs page under `docs/content/docs/Technical/mcp.md`: token setup, client config snippets (Claude Code, Claude Desktop via `mcp-remote`, Cursor), tool reference, safety notes.
2. Register in the MCP registry; announce to self-hosters (works out of the box behind their own host).
3. Optional: `mcp-atlos` npm stdio shim for header-incapable clients.

### Phase 3 — Later enhancements

- MCP resources & subscriptions (live incident updates via PubSub + SSE).
- Multi-project sessions (needs a token model change — tokens are strictly project-scoped today; the recently reverted instance-wide-token work suggests this is an open product question, not a technical one).
- File upload tool once ecosystem patterns mature; export tools (CSV/full) mirroring `ExportController`.

## 6. Security considerations

- **Capability ceiling is the token.** MCP adds no authority: every write path re-checks `Platform.Permissions.can_api_token_*`, `Security` mode, and project match, same as the REST API. Tokens remain owner-created, project-scoped, billing-gated.
- **Prompt-injection surface:** incident descriptions, comments, and source URLs are adversarial by nature in OSINT work. Tool outputs are data, but we should (a) document this prominently for users, (b) keep destructive operations out of the tool surface entirely (no delete/restrict tools in v1), and (c) require `message` explanations on attribute edits so agent actions are auditable in the feed.
- **Researcher safety:** never inline media content; return signed artifact URLs (already time-limited) and surface `attr_sensitive` flags in every incident payload so clients can warn.
- **Rate limiting:** the API currently has none per-token; MCP agents are chattier than scripts. Add a simple per-token rate limit (e.g., Hammer) to the shared `:check_api_token` pipeline as part of Phase 0/1.

## 7. Open questions

1. Should `update_incident_attribute` be allowed on restricted attributes (`is_restricted`, privileged values) with an `:edit` token, or should MCP be conservative and refuse? (Proposal: refuse in v1.)
2. Library choice: `anubis_mcp` vs. hand-rolled Plug — prototype both in a spike; pick based on maintenance surface.
3. Hosted Atlos: do we want MCP behind a feature/billing flag (`Plan.allowed_api` already exists — reuse it?).
4. Naming: `/mcp` vs `/api/mcp`; whether Phase 0 REST fixes ship as v2 changes or start a v3 namespace.
