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

Please note that the API is in beta and not all operations are supported; if you need something, please get in touch via [email](mailto:contact@atlos.org) or on [Discord](https://discord.gg/gqCcHc9Gav).

## Create an API token
1. Navigate to the project for which you need an API token.
2. Navigate to the **Access** page of the project.
3. Press the **Create** button in the API Tokens section of the page.
4. Assign the token a name, write a description of what the token is used for, and select permissions for the token.
5. Click the **Create Token** button.


## API Vocabulary
Atlos' API uses several terms that users of Atlos might be unfamiliar with:
- **Slugs** are six character unique IDs for incidents. `AD12H45` is the slug in `CIV-AD12H45`. Atlos displays incidents' slugs in the web app. Slugs are also the last part of an incident's URL.
- **IDs** are unique identifiers for projects, pieces of source material, and artifacts. They look like this: `d0bce96b-4468-44be-a0d1-419dbd96a879`. While incidents have IDs that are sometimes exposed in the API, API endpoints use slugs to refer to incidents and IDs to refer to everything else.
- **Artifacts** are the individual files in a piece of source material. A piece of source material, like an archived link, may have zero, one, or more photos, videos, and other files associated with it. This is the hierarchy of content on Atlos:

{{< filetree/container >}}
    {{< filetree/folder name="Project 1" >}}
        {{< filetree/folder name="Incident 1" >}}
            {{< filetree/folder name="Source Material 1">}}
                {{< filetree/file name="Artifact 1" >}}
                {{< filetree/file name="Artifact 2" >}}
            {{< /filetree/folder >}}
            {{< filetree/folder name="Source Material 2">}}
            {{< /filetree/folder >}}
        {{< /filetree/folder >}}
        {{< filetree/folder name="Incident 2" >}}
        {{< /filetree/folder >}}
    {{< /filetree/folder >}}
{{< /filetree/container >}}

## Authentication
API tokens are sensitive—they allow read and write access to your project. By default, every API token will have access to a `READ` endpoint. 

To authenticate against the API, include an `Authorization` header and set its value to `Bearer <your token>`. In python, that looks like this:
```python
requests.get(
    f"https://platform.atlos.org/api/v2/{endpoint}",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"cursor": cursor},
)
```

## Pagination
Paginate using the `cursor` query parameter, whose value is provided by the `next` and `previous` keys in the response. Results are available under the `results` key.

## API Endpoints
The Atlos API supports `GET` and `POST` endpoints. All `GET` endpoints return 30 results at a time. 

### Get all incidents in a project
`GET /api/v2/incidents` returns all incidents in a project.
- **Sort—** Most recently modified incidents are listed first. 
- **Filter—** You can optionally pass search parameters to filter results using the same format as the in-platform incident search page's URL. For example, to return only incidents with the status "To Do" or "Cancelled", query `/api/v2/incidents?attr_status[]=To+Do&attr_status=Cancelled`.

```python
requests.get(
    f"https://platform.atlos.org/api/v2/incidents?attr_status[]=To+Do&attr_status=Cancelled",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"cursor": cursor},
)
```

### Get all source material in a project
`GET /api/v2/source_material` returns all source material in a project.
- **Sort—** Most recently modified source material is listed first.

```python
requests.get(
    f"httpps://platform.atlos.org/api/v2/source_material",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"cursor": cursor},
)
```

### Get a specific piece of source material
`GET /api/v2/source_material/:id` returns the source material with the given ID.

```python
requests.get(
    f"https://platform.atlos.org/api/v2/source_material/d0bce96b-4468-44be-a0d1-419dbd96a879",
    headers={"Authorization": f"Bearer {api_token}"}
)
```

### Create a new piece of source material
`POST /api/v2/source_material/new/:slug` creates a new piece of source material in the already-existing incident with slug `:slug`. This endpoint has two optional parameters:
- `url`, a URL for Atlos to archive (optional). 
- `archive`, a boolean value indicating whether Atlos should archive the URL in `url` (optional). 

Note that if you opt not to archive a link, you will create an empty piece of source material to which you can add artifacts later.

```python
requests.post(
    f"https://platform.atlos.org/api/v2/source_material/new/ABCDEF",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"url": "https://atlos.org", "archive": True},
)
```

### Set source material metadata
`POST /api/v2/source_material/metadata/:id/:namespace` with parameter `metadata` (JSON dictionary) sets the metadata of the given piece of source material (identified by its ID) in the given namespace. Namespaces are used to separate different types of metadata. Typically, an API user would use a namespace that is unique to their application (for example, Bellingcat's [auto archiver](https://github.com/bellingcat/auto-archiver) uses the `auto-archiver` namespace). This endpoint expects a JSON content type.

Using this endpoint will overwrite any existing metadata in the given namespace. Metadata is returned by the API and may be shown in the Atlos web interface as well.

```python
requests.post(
    f"https://platform.atlos.org/api/v2/source_material/metadata/:id/auto-archiver",
    headers={"Authorization": f"Bearer {api_token}"},
    json={"metadata": {"key": "value"}},
)
```

### Upload a file (artifact) to a piece of source material
`POST /api/v2/source_material/upload/:id` uploads a file to the piece of source material with ID `:id`. This endpoint has two parameters:
- `file`, which should be sent as a multipart form request (required).
- `title`, the title of the file (optional). If provided, Atlos will be display the title in the interface.

Note: To upload a file to a new incident, you must first [create an empty piece of source material](/technical/api/#create-a-new-piece-of-source-material). Files always belong to a piece of source material.

```python
requests.post(
    f"https://platform.atlos.org/api/v2/source_material/upload/:id",
    headers={"Authorization": f"Bearer {api_token}"},
    params={
        "title": media.properties
    },
    files={"file": (os.path.basename(media.filename), open(media.filename, "rb"))},
)
```

### Get updates and comments
`GET /api/v2/updates` returns all updates (including comments) in a project. 
- **Sort—** Most recent updates are listed first. 
- **Filter—** To see updates for a specific incident, append the `slug` query parameter to the endpoint (e.g., `/api/v2/updates?slug=incident-slug`). The slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints.

```python
requests.get(
    f"https://platform.atlos.org/api/v2/updates?slug=ABCDEF",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"cursor": cursor},
)
```

### Add a comment to an incident
`POST /api/v2/add_comment/:slug` adds a comment to the incident with slug `:slug`. This endpoint has one required parameter:
-  `message` contains the string contents of the comment.

```python
requests.post(
    f"https://platform.atlos.org/api/v2/add_comment/ABCDEF",
    headers={"Authorization": f"Bearer {api_token}"},
    params={"message": "This is a comment."},
)
```

### Update an incident's attribute value
`POST /api/v2/update/:slug/:attribute_identifier` updates the attribute `:attribute_identifier` in the incident with slug `:slug`. It has two parameters:
- `value`, the new value of the attribute (required). For text or single-select attributes, `value` should be a string. For multi-select attributes, `value` should be a list of strings.
- `message`, a string to be displayed as an explanation for the update (optional). If `message` is provided, it will be added as a comment to the incident (as part of the tracked change). 

You can find the `:attribute_identifier` in the **Access** pane of your project. Attributes' names in the Atlos interface are different from their API identifiers: 
- Core attributes have string names (such as `description` and `status`).
- Custom attributes are identified by a long ID. 
  
To find the name of an attribute, open the attribute editing window and copy the last part of the URL. For example, in the URL `https://platform.atlos.org/incidents/EPIHRZ/update/c37c2619-3377-4b97-989b-f3481c7f1948`, the attribute's ID is `c37c2619-3377-4b97-989b-f3481c7f1948`. 

```python
requests.post(
    f"https://platform.atlos.org/api/v2/update/ABCDE/status",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"value": "To Do", "message": "This is a comment."},
)

requests.post(
    f"https://platform.atlos.org/api/v2/update/ABCDE/c37c2619-3377-4b97-989b-f3481c7f1948",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"value": ["Civilian-military interaction", "Protest"], "message": "This is a comment."},
)
```


### Create an incident
`POST /api/v2/incidents/new` creates a new incident. It has two required parameters:
- `description`, the incident's description. `description` should be a string of at least 8 characters.
- `sensitive`, a string array of the incident's sensitivity. That should be either `["Not Sensitive"]`, or any combination of the values `["Graphic Violence", "Deceptive or Misleading", "Personal Information Visible"]`.

It also has many optional parameters:
- Any attribute, both core and custom. See below for more information on accessing attributes' API identifiers.
- `status`, the incident's status. By default, the incident will be created as "To Do". If you include this field, you can set the incident to one of: `"To Do"`, `"In Progress"`, `"Ready for Review"`, `"Help Needed"`, `"Completed"`, or "`Canceled"`. 
- `urls`, which should contain a list of urls to be archived as distinct pieces of source material. For more granular control over source material metadata, we recommend using the field in conjunction with the source material creation endpoint and the source material metadata update endpoint. 

Note that it is not currently possible to set an incident's Assignees or deleted status from this endpoint.

Attributes' names in the Atlos interface are different from their API identifiers: 
- Core attributes have string names (such as `description` and `status`).
- Custom attributes are identified by a long ID. 

You can find attributes' API identifiers in the **Access** pane of your project. 

```python
requests.post(
    f"https://platform.atlos.org/api/v2/incidents_new",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"description": "Test incident created via the API", 
            "sensitive": ["Not Sensitive"]
    }
)

requests.post(
    f"https://platform.atlos.org/api/v2/incidents_new",
    headers={"Authorization": f"Bearer {self.api_token}"},
    json={"description": "Test incident created via the API",
            "sensitive": ["Not Sensitive"],
            "more_info": "This incident was created via the Atlos API",
            "status": "In Progress",
            "urls": ["https://docs.atlos.org"],
            # This ID is the identifer for the project's multi-select 'Impact' attribute
            "cf7a3ed7-2c26-428a-b56c-2cc3f98d7a2c": ["Residential"]
    }
)
```