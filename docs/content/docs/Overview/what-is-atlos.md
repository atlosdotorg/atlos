---
title: What is Atlos?
description: Atlos is a non-profit and open source platform that enables visual investigators to collaborate at scale. 
weight: 1
---

Atlos is a non-profit and open source platform that enables visual investigators to collaborate at scale. 

## Atlos solves a process problem
Atlos is a solution to a process problem: general-purpose tools like spreadsheets don’t adequately support large-scale visual investigations. We’re big fans of Google Sheets, but there are several areas where spreadsheets fall short in some large-scale investigations:

1.  **Integrity—** Spreadsheets make it too easy to edit data inadvertently. Investigations with many contributors also often require granular access controls, but spreadsheets generally allow all investigators to edit all content. 
2.  **Visual content—** Spreadsheets weren’t built for visual media. There’s no space for photos or videos—investigators’ evidence—in a spreadsheet. This makes deduplication,  media verification, and incident analysis difficult. 
3.  **Researcher safety—** Spreadsheets aren't suitable for sensitive content. Visual investigators contend with graphic and other disturbing content. They deserve tools that help keep them safe. 
4.  **Collaboration—** Spreadsheets can’t handle large-scale collaboration. Investigators have no space to discuss the details of a particular incident with one another. When they turn to a separate system for collaboration, important evidence and a record of the investigative process are left behind when data is entered back into the spreadsheet. 

## What we do
Atlos is purpose-built to visual investigators’ workflows. We aim to solve each of the challenges spreadsheets pose for visual investigators:
1.  **Integrity—** Atlos [tracks every change](/incidents/comments-and-the-feed/#change-tracking) to the underlying data, so investigators have a clear record of the investigative process. 
2. **Visual content—** Atlos [automatically archives](/incidents/source-material/#automatic-archival) photos and videos, tweets and TikToks, and even entire webpages. We display this content directly within the platform, so investigators can easily refer to their evidence.
3.  **Researcher safety—** Atlos makes it easy to warn collaborators that content media contains [graphic or disturbing content](/incidents/metadata/#sensitivity). We also follow industry safety best practices, including by displaying all content in grayscale by default. 
4. **Collaboration—** We’ve baked in key project-management tools right into the platform. While Atlos workspaces are private by default, [sharing](/investigations/collaboration/#how-to-add-a-member) a project is just as easy as sending a Google Doc: Investigators simply send collaborators an invite link and choose from several fine-grained permission levels.

## What we don't do
We think Atlos is a powerful tool for large teams conducting ambitious visual investigations. We also know Atlos isn’t for everyone. For many investigative workflows, there are better tools than Atlos. Atlos is not a tool for:
-  **Legally-admissible evidence archival—** Atlos is not intended for legally-admissible evidence archival or other forensic evidence preservation. We archive media so it can be easily viewed and preserved during a journalistic investigation. If you're looking for forensic preservation, [Mnemonic](https://mnemonic.org/) is a leader in forensic media archival. 
- **Geospatial visualization—** Atlos’ map is intended to make searching the catalog easier. While our map is helpful for visualizing trends, Atlos is not primarily a mapping platform—there’s better mapping software available. We’re big fans of [Felt](https://felt.com/), which is compatible with Atlos’ CSV export. 
- **Publishing—** Atlos is currently not a publishing tool; Atlos projects cannot be viewed by anyone online. We do [plan](/overview/roadmap/#publishing-tools) on adding publishing features in the next few months. For now, if you’re looking to publish the dataset you’ve constructed on Atlos, we recommend using our API to integrate with a third-party mapping suite like [TimeMap](https://github.com/forensic-architecture/timemap).
- **Quick tagging of a small dataset—** If you’re working alone or on a small team to quickly tag a small dataset that is not—and won’t become—organized around incidents, spreadsheet software is probably best for you. Atlos is helpful in many cases, but spreadsheets are also a great—and far more flexible—tool. 