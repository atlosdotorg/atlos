---
title: Self-host Atlos
description: Host Atlos on your own server.
type: docs
sidebar:
  open: true
weight: 2
---

Atlos is open source, and you are welcome to self-host it on your own infrastructure. 

## Should I self-host?
Self-hosting is a great option for larger organizations that have dedicated, experienced technical teams that can help maintain the infrastructure. While we work hard to keep Atlos simple, self-hosting the platform does require significant technical expertise. We generally only recommend self-hosting Atlos for organizations with:
- A dedicated technical team who can manage the infrastructure
- Special data security or governance requirements that prevent the use of our hosted platform

While anyone is welcome to self-host, we recommend against self-hosting for most organizations. (We also discourage self-hosting for organizations that do so principally to save on the costs of using our hosted version; the cost of managing and purchasing/renting your own servers to run Atlos robustly is almost certainly going to be more expensive than our hosted version.) Our hosted version is designed to be secure, reliable, and easy to use, and we recommend that most organizations use it.

## How to self-host
For organizations that do self-host, we encourage you to follow roughly the same deployment steps that we use for our hosted version, though you will have to adapt those steps to your own infrastructure.

At a high level, here are the infrastructure components you'll need:
- A PostgreSQL database
- Some way to run a containerized web application on the internet (e.g., Azure Container Apps, Fly.io, Heroku, etc.)
- S3-compatible object storage for media (e.g., Amazon AWS)

For more information on self-hosting, refer to our [development and architecture guide](https://github.com/atlosdotorg/atlos/blob/main/platform/README.md) on GitHub.

## Support for self-hosting orgs
We are also able to provide official and priority support channels to self-hosting organizations that contribute financially to the project. For all organizations, we are happy to answer questions and provide guidance on our [Discord](https://discord.gg/gqCcHc9Gav) server to the extent that we are able.

If you have any questions about self-hosting, please feel free to reach out to us on [Discord](https://discord.gg/gqCcHc9Gav) or via [email](contact@atlos.org).