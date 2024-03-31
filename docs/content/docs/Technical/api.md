---
title: API
description: Integrate Atlos with third-party services.
type: docs
sidebar:
  open: true
weight: 1 
---


Atlos offers a project-scoped API to help investigators integrate with third-party services like mapping and archival applications.

You can learn more about the API authentication scheme and endpoints below. API tokens are only accessible to project owners.

Please note that the API is in beta and not all operations are necessarily supported; if you need something, please get in touch via [email](mailto:contact@atlos.org) or on [Discord](https://discord.gg/gqCcHc9Gav).

## How to create an API token
1. Navigate to the project for which you need an API token.
2. Navigate to the **Access** page of the project.
3. Press the **Create** button in the API Tokens section of the page.
4. Assign the token a name, write a description of what the token is used for, and select permissions for the token.
5. Click the **Create Token** button.

API tokens are sensitive—they allow read and write access to your project.

To authenticate against the API, include an `Authorization` header and set its value to `Bearer <your token>`. 

## API Reference  
The Atlos API supports `GET` and `POST` endpoints. All `GET` endpoints return 30 results at a time. By default, every API token will have access to a `READ` endpoint. 

You can paginate using the `cursor` query parameter, whose value is provided by the `next` and `previous` keys in the response. Results are available under the `results` key.

### Get incidents
`GET /api/v2/incidents` returns all incidents, with the most recently modified incidents listed first. You can optionally pass search parameters to filter the results using the same format as the in-platform incident search page's URL. For example, to only return incidents with the status "To Do" or "Cancelled", you would query `/api/v2/incidents?attr_status[]=To+Do&attr_status=Cancelled`.

Example:

```python
requests.get(
    f"{self.atlos_url}/api/v2/incidents",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={"cursor": cursor},
)
```

### Get source material
`GET /api/v2/source_material` returns all source material, with the most recently modified source material listed first.

Example:

```python
requests.get(
    f"{self.atlos_url}/api/v2/source_material",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={"cursor": cursor},
)
```

### Create a new piece of source material
`POST /api/v2/source_material/new/:slug` with parameters `url` (optional) and and `archive` (optional, set value to `true` if you want to enable Atlos archival of the source material) creates a new piece of source material for the incident with slug `:slug` (the slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints).

Example:

```python
requests.post(
    f"{self.atlos_url}/api/v2/source_material/new/ABCDE",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={"url": "https://atlos.org", "archive": True},
)
```

### Set source material metadata
`POST /api/v2/source_material/metadata/:id/:namespace` with parameter `metadata` (JSON dictionary) sets the metadata of the given piece of source material (identified by its ID) in the given namespace. Namespaces are used to separate different types of metadata. Typically, an API user would use a namespace that is unique to their application (for example, Bellingcat's [auto archiver](https://github.com/bellingcat/auto-archiver) uses the `auto-archiver` namespace). This endpoint expects a JSON content type.

Using this endpoint will overwrite any existing metadata in the given namespace. Metadata is returned by the API and may be shown in the Atlos web interface as well.

Example:

```python
requests.post(
    f"{self.atlos_url}/api/v2/source_material/metadata/:id/auto-archiver",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"metadata": {"key": "value"}},
)
```

### Upload a file to a piece of source material
`POST /api/v2/source_material/upload/:id` with parameter `file` uploads a file to the given piece of source material (identified by its ID). The file should be sent as a multipart form data request. You may optionally also include a `title` parameter to set the title of the file.

Example:

```python
requests.post(
    f"{self.atlos_url}/api/v2/source_material/upload/:id",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={
        "title": media.properties
    },
    files={"file": (os.path.basename(media.filename), open(media.filename, "rb"))},
)
```

### Get updates and comments
`GET /api/v2/updates` returns all updates (including comments), with the most recently modified updates listed first. Optionally pass a `slug` query parameter to filter by incident (e.g., `/api/v2/updates?slug=incident-slug`). The slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints.

Example:

```python
requests.get(
    f"{self.atlos_url}/api/v2/updates",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={"cursor": cursor},
)
```

### Add a comment to an incident
`POST /api/v2/add_comment/:slug` with string parameter `message` adds a comment to the incident with slug `:slug` (the slug is the last part of the URL for the incident, and is also available in the `slug` field of the incident object).

Example:

```python
requests.post(
    f"{self.atlos_url}/api/v2/add_comment/ABCDE",
    headers={"Authorization": f"Bearer {self.api_token}"},
    params={"message": "This is a comment."},
)
```

### Update an incident's attribute value
`POST /api/v2/update/:slug/:attribute_name` with parameter `value` and optional string parameter `message` updates the value of `attribute_name` to `value` for the incident with slug `:slug` (the slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints). 

If `message` is provided, it will be added as a comment to the incident (as part of the tracked change). 

The value of `attribute_name` is available in the URL of the incident page when editing the incident. 

Core attributes have string names (such as `description` and `status`) while custom attributes are identified by their UUID. 

The `value` must be a string for text-based or single-select attributes, and a list of strings for multi-select attributes. 

Example:

```python
requests.post(
    f"{self.atlos_url}/api/v2/update/ABCDE/status",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"value": "To Do", "message": "This is a comment."},
)
```