# Roles on Atlos

On Atlos, different users have access to different capabilities via _roles_. This document spells out how roles work on Atlos.

Users can have multiple roles, and each role provides access to certain actions. By default, users have no roles.

# Role: `trusted`

Users with the `trusted` role can...

- Edit an incident's tags
- Create new incidents without them automatically being tagged, per the instance configuration (Put differently: incidents created by regular users can be automatically tagged as volunteer-created, for example. Incidents created by users with the `trusted` role are not automatically tagged this way.)
- Mark an incident's status as `Completed` or `Cancelled`
- View hidden incidents
- Set incidents as frozen or hidden
- Edit and comment on frozen or hidden incidents
- Remove media from incidents
- View media removed from an incident
- Generate invite codes for other users to join Atlos
- Hide individual updates/comments on incidents

# Role: `admin`

Users with the `admin` role have full access to everything on Atlos. They can do anything a user with the `trusted` role can do, plus:

- Edit any user's information (including suspending users _and_ making other users admins)
- Delete and restore incidents (this is distinct from marking incidents as hidden; hidden incidents still show up in search results and on the map for `trusted` and `admin` users, while deleted incidents do not appear on the map or in search results for anyone)
- Access Atlos when the `No Access` security mode is enabled
- Edit and comment on incidents when the `Read Only` security mode is set
- Access all features in Adminland, which includes:
  - Viewing and searching all activity on Atlos
  - Posting announcements
  - Viewing the catalog of deleted incidents
  - Changing Atlos' security mode (i.e., making Atlos read-only, or temporarily blocking anyone from logging in)
  - Viewing all registered users, their emails, their MFA status, etc.
  - Bulk upload new incidents
  - Manage API keys
