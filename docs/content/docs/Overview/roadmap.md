---
title: Roadmap and changelog
description: Where Atlos is headed next.
weight: 4
---

We're actively developing Atlos. The platform is a product of the investigative community; we value your input. If you think something's missing from our roadmap, let us know via [email](mailto:contact@atlos.org) or on [Discord](https://discord.gg/gqCcHc9Gav).

## Roadmap
Here's what we're working on next:

{{% steps %}}

### New customization options for attributes and metadata
Atlos currently lets investigators customize and add new attributes. We're expanding data model configurability in two ways:
- Investigators will be able to group and sort attributes, making it easier to organize information in investigations with a complex data model.
- Investigators will be able to customize the values and descriptions of metadata fields like status and sensitivity, because Atlos should be able to match each team's unique workflow and safety standards.\
[Track our progress](https://github.com/atlosdotorg/atlos/milestone/15).

### Backup codes for MFA
We implore investigators to enable multi-factor authentication on their Atlos accounts. But if you lose access to your authenticator app, you'll
be locked out of Atlos. We're adding single-use recovery codes so that investigators have a backup system to log in to Atlos. [Track our progress](https://github.com/atlosdotorg/atlos/milestone/10).

### Pricing plan 
To support the costs of development, maintenance, and support, we're implementing a pricing plan in the next month. The model includes a generous [free tier](/overview/pricing/) and we're optimistic there's a plan for everyone. 

### Better documentation for self-hosting
We're seeing increased interest in self-hosting Atlos and want to make it as easy—and safe—as possible to do so. We're planning to:
- Create named releases for Atlos, so organizations know what they're getting when they deploy a new version of the platform.
- Make our self-hosting documentation easier to navigate.
- Add recommendations for database-level logging and security best practices.\
[Track our progress](https://github.com/atlosdotorg/atlos/milestone/18).

### Simplified permissions schema
Atlos has lots of moderation tools—investigators can hide, freeze, and delete incidents, minimize and remove source material, and archive projects. We plan to simplify this schema so it's more clear which investigators can do what, when. [Track our progress](https://github.com/atlosdotorg/atlos/milestone/14).

### Decoupling source material from incidents
People want a place to throw in source material before they’re ready to define their data model. Source material should be a first-class citizen on Atlos. More details to come. [Track our progress](https://github.com/atlosdotorg/atlos/milestone/19).

### Linking incidents to one another
Incidents do not exist in isolation, and the ability to “network” incidents is a fairly common feature request. More details to come.

### Improved incident page
Once source material is decoupled from incidents, we plan to improve the incident page to reduce clutter, increase focus, and make routine actions faster to complete. More details to come. 

### Publishing tools 
We've heard the requests. We plan to add the ability to export and self-host a map of incidents that looks just like the once you'd find on Atlos' incidents page. More details to come.

### Improved home page
We plan to make it easier and faster to catch up on your team's progress and pick back up your work. More details to come.

### Improve attribute filtering
Atlos makes it easy to filter by some attributes; it should be just as easy to filter by any attribute. More details to come. [Track our progress](https://github.com/atlosdotorg/atlos/milestone/20)

{{% /steps %}}


## Changelog
Here are some major updates we've shipped recently:
{{% steps %}}

### Help center
We published a detailed help center to help investigators answer their questions about Atlos faster. [Check it out](https://docs.atlos.org).

### Full export
Atlos has always supported CSV export of project data; we now support a full export of projects' source material, metadata, attribute information, and updates. 

### Project sharing with an invite link
We've added the ability to invite teammates to projects—and Atlos itself—with an invite link. 

### Project archival
Consistent with our approach to [data integrity](/incidents/#delete-an-incident), we've replaced the ability to delete projects with the ability to archive them, which makes their data read-only.

### Find-anything search
Atlos' attributes, source material, and comments comprise a rich database of information that could be helpful in an investigation. We've made all of that data easily searchable. Press `ctrl` + `K` to search from anywhere.

### New incident creation on-the-go
Creating a new incident should be fast and easy—all you have to do is click `ctrl` + `I` to create a new incident from anywhere on Atlos. 

### Project-scoped API
The new API enables investigators to integrate third-party archival and publishing systems into Atlos.

{{% /steps %}}