---
title: FAQ
weight: 5
---

## Can I export my data from Atlos?
Yes—it's easy to export your entire Atlos catalog into a CSV at the click of a button. [Learn more](/investigations/import-and-export-data/#how-to-export-data) about exporting your data.

## Can I import a spreadsheet?
Yes. You can upload a CSV to add many incidents at the same time. [Learn more](/investigations/import-and-export-data/#how-to-import-data) about bulk importing data.  

## How should I define an incident? 
Incidents are the core unit of content on Atlos. They refer to specific events that are depicted by one or more pieces of source material. There's no one way to define an incident in your investigation. [Learn more](/incidents/incidents/#incidents-are-the-atoms-of-atlos) about how to scope incidents. 

## Is Atlos safe for my investigation?
It depends. We take safety incredibly seriously; Atlos also underwent an independent security audit in summer 2023. But like all digital tools, using Atlos also carries risk. There's no short answer to this question, so we've dedicated an entire section of the Help Center to our [security and risk model](/safety-and-security/risk-model/). 

## What infrastructure does Atlos use? 
### Hosting
Right now, we deploy Atlos in two places: on the lovely Fly.io (who sponsor us—thank you!) and on Microsoft Azure (who also sponsor us—thank you!).

We are in the middle of a transition of our infrastructure from Fly.io to Azure. While the Fly.io platform is great, right now we need a more robust and battle-tested environment to run our application (and especially our database), and we ran into enough issues with Fly.io that we decided to make the leap to Azure.

### Media storage
We store media in an Amazon S3 bucket. 

## Can I self-host Atlos?
Yes! If you're more comfortable using a self-hosted instance of Atlos or you plan to customize the platform, you can self-host Atlos. For more on self-hosting, refer to our development, architecture, and deployment [guide](https://github.com/atlosdotorg/atlos/blob/main/platform/README.md).








