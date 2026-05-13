---
title: Admin API access
description: Instance-wide API tokens for admins.
weight: 6
---

Atlos admins can create **instance-wide v2 API tokens** that grant access to every project on the instance through a single token. This is useful for instance-level integrations—backups, cross-project reporting, or admin tooling—where a project-scoped token would be impractical.

{{< callout type="warning" >}}
**This page explains admin-only features.**
If you don't administer an instance of Atlos, these features are not relevant to your use of the platform. Project owners create project-scoped API tokens from the project's **Access** page.
{{< /callout >}}

## Token kinds

Atlos has three kinds of API tokens:

| Kind | Scope | Created by | Status |
| --- | --- | --- | --- |
| **Instance-wide v2** | Every project on the instance | Admins, from Adminland → API Access | Active |
| **Project-scoped v2** | A single project | Project owners, from a project's **Access** page | Active |
| **Legacy v1** | Instance-wide, read-only, limited to `/api/v1/media` and `/api/v1/media_versions` | Admins | Deprecated; existing tokens still work, but new ones can't be created |

## Create an instance-wide v2 token

1. Navigate to **Adminland**.
2. Click on the **API Access** tab.
3. Click **Create**.
4. Give the token a name and description, and select the permissions (`read`, `comment`, `edit`) you want it to have.
5. Click **Create API Token**.

The token's secret value is shown exactly once — store it somewhere safe. You can revoke a token at any time from the API Access page.

## Using an instance-wide token

Authentication, pagination, and endpoint shapes are identical to project-scoped tokens. See the main [API documentation](/technical/api/) for the full endpoint reference.

There is one difference for admins:

- **Creating an incident** (`POST /api/v2/incidents/new`) requires a `project_id` in the request body when using an instance-wide token, since the token isn't bound to a specific project. Project-scoped tokens ignore any `project_id` in the body — the token's project always wins.

All other endpoints work identically. List endpoints (`GET /api/v2/incidents`, `GET /api/v2/source_material`, `GET /api/v2/updates`) return results from every project on the instance, and single-resource endpoints derive the project from the resource itself.

## Legacy v1 endpoints (deprecated)

Legacy v1 tokens are read-only and limited to two endpoints. New v1 tokens can't be created, but existing tokens continue to work. Migrate to instance-wide v2 tokens when feasible.

### Endpoints

- `GET /api/v1/media` — Returns all incidents across the instance. Most recently modified incidents are listed first.
- `GET /api/v1/media_versions` — Returns all source material across the instance. Most recently modified source material is listed first.

(The endpoint paths still use the legacy `media` and `media_versions` names, but the responses are the same `incidents` and `source material` records that v2 returns.)

### Authentication

Include an `Authorization` header and set its value to `Bearer <your token>`.

### Pagination

All v1 endpoints return 30 results per page. Paginate using the `cursor` query parameter, whose value is provided by the `next` and `previous` keys in the response. Results are available under the `results` key.
