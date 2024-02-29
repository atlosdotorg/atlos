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

### Get source material
`GET /api/v2/source_material` returns all source material, with the most recently modified source material listed first.

### Get updates and comments
`GET /api/v2/updates` returns all updates (including comments), with the most recently modified updates listed first. Optionally pass a `slug` query parameter to filter by incident (e.g., `/api/v2/updates?slug=incident-slug`). The slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints.

### Add a comment to an incident
`POST /api/v2/add_comment/:slug` with string parameter `message` adds a comment to the incident with slug `:slug` (the slug is the last part of the URL for the incident, and is also available in the `slug` field of the incident object).

### Update an incident's attribute value
`POST /api/v2/update/:slug/:attribute_name` with parameter `value` and optional string parameter `message` updates the value of `attribute_name` to `value` for the incident with slug `:slug` (the slug is the last part of the URL for the incident, and is also available in the ‘slug’ field of the incident object returned by other endpoints). 

If `message` is provided, it will be added as a comment to the incident (as part of the tracked change). 

The value of `attribute_name` is available in the URL of the incident page when editing the incident. 

Core attributes have string names (such as `description` and `status`) while custom attributes are identified by their UUID. 

The `value` must be a string for text-based or single-select attributes, and a list of strings for multi-select attributes. 