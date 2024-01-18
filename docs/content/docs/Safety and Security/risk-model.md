---
title: Security and risk model
description: A guide to Atlos' approach to platform security. 
type: docs
sidebar:
  open: true
---

## Guiding principles
Atlos is a platform for open-source visual investigations. And while Atlos often makes visual investigations safer and more secure—for example, by enforcing access controls and by limiting exposure to graphic media—using Atlos also carries risks. Here are some key things to keep in mind as you use Atlos:

- **No online platform is 100% secure, and Atlos isn’t an exception.** If the exposure of your data could lead to significant harm, don’t use Atlos.\
    {{< callout type="warning" >}}
  We recommend against using Atlos for closed source investigations (i.e., investigations where the source material isn’t publicly available online).
{{< /callout >}}


- **If legally required, we will have to disclose your data.** If there is a legal requirement for us to share data with a government or law enforcement agency with appropriate jurisdiction, we will have no choice but to comply.
    {{< callout type="warning" >}}
  If you are concerned about protecting your identity from law enforcement, protect your identity from us (e.g., employ a VPN and pseudonym when using Atlos).
{{< /callout >}}


- **Our automatic archival isn’t perfect.** When you add a link to an incident’s source material, Atlos will attempt to archive the page—and any media on that page—automatically. While generally robust, our archival system has limitations, and it’s not meant for evidentiary or forensic purposes. For example, our archival system can’t archive pages that require authentication (e.g., private Telegram links), it may miss media on certain pages, and it might sometimes break.
    {{< callout type="warning" >}}If you plan to use Atlos for evidentiary purposes—or require “forensic” archival—you should independently archive your source material.{{< /callout >}}

- **Be mindful of your mental health.** Visual investigations can lead to vicarious trauma, especially when graphic media is involved. Atlos takes several steps to minimize the psychological impact of this content, but these techniques aren’t foolproof.
    {{< callout type="warning" >}}Know your limits. Take breaks. Give yourself—and your team—space.{{< /callout >}}

- **Nothing is forever.** While we plan to support the Atlos platform far into the future, it is possible that circumstances will change and the platform will shut down. If Atlos does shut down, it will almost certainly be after a long sunsetting period, and we will work with you to migrate your workflow elsewhere (e.g., to a self-hosted version of Atlos).
    {{< callout type="warning" >}}We strongly recommend periodically exporting your data from the Atlos platform and backing it up elsewhere.{{< /callout >}}

The remainder of this page details our threat model. If you have any questions, please contact us at [contact@atlos.org](mailto:contact@atlos.org).

## Data security
We take the security of data on Atlos very seriously. At a high level, Atlos collects four types of data: user and investigation data, source material, and usage data. This section will lay out how we protect the confidentiality, integrity, and availability of these four categories of data.

Note that Atlos underwent an independent security audit in summer 2023.

Note that **we would be required to honor valid legal information requests** (e.g., subpoenas and other court orders) for authorities with jurisdiction over us. Atlos is based out of California in the United States. Assume that this caveat applies to all the types of information listed below, even if not explicitly mentioned.

### User and investigation data
User and investigation data refers to information about Atlos users themselves (including their usernames, email addresses, authentication information, and billing information), projects on Atlos (their names, members, descriptions, data models, etc.), and incidents on Atlos (their attributes, updates, and source material).

Technically, user and investigation data refers to all the data we store in PostgreSQL.

#### What could go wrong?
Atlos is a standard web application, and so we store our user data in a centralized database. In the worst-case scenario, an adversary might achieve remote code execution capabilities on our web application, which would allow for the following:

- An adversary (e.g., an adversarial government) might access private user and investigation data (and potentially also make it public), thus compromising the **privacy** and **confidentiality** of Atlos users and their investigations. (Note that Atlos will respond to valid law enforcement requests for jurisdictions of which we are part.)
- Atlos user and investigation data might be lost, deleted, or become otherwise unavailable, compromising the **availability** of Atlos.
- Atlos user and investigation data might be subtly altered (e.g., changing an incident’s data, deleting an incident/project, or altering a user’s authentication information) without proper authorization, violating the **integrity** of our data. This type of attack might allow an adversary to subtly alter data on Atlos (e.g., in your investigation) without leaving any obvious record.

Barring a user achieving full remote code execution ability on our instance, several other risks exist:
- A user’s account may be compromised (e.g., phished), thus allowing an adversary to act on that user’s behalf, as well as access and/or edit any information on Atlos accessible to that user.
- A project owner may invite a malicious user to their project by accident; that malicious user may then try to cause chaos by editing and deleting data.

#### How does Atlos address this risk?
We take several steps to protect the confidentiality, availability, and integrity of our user data:
- To protect the confidentiality of user and investigation data, we do our best to follow all relevant security best practices in our application. We also run our database on a server not directly connected to the public internet (though that does not prevent an attacker from accessing our database by way of exploiting our public web application).
- To protect the availability of user and investigation data, we take regular backups in two ways (note that these backups are stored in an immutable form on AWS S3):
  - Continuous [“WAL” style](https://www.postgresql.org/docs/current/continuous-archiving.html) PostgreSQL backups— these backups capture changes to our data as they happen, and allow us to restore Atlos to any five-minute interval. We currently store these backups for at least seven years.
  - Full logical backups every six hours— we automatically generate a full logical backup of our database every six hours, which is stored in an Amazon AWS bucket. These backups are encrypted to a public key using [age encryption](https://github.com/FiloSottile/age); only Miles McCain and Noah Schechter (the Atlos co-founders) have access to the corresponding private key.
- To protect the integrity of user and investigation data, we conduct robust audit logging of all major, data-changing events in the application. These audit logs are retained for 90 days and are stored in Slack (see [Usage information](/safety-and-security/risk-model/#usage-information) below). However, an adversary who has achieved remote code execution ability on our web application would be able to bypass this audit logging system. (They would not, however, be able to retroactively edit our backups, thus making their changes to our data hypothetically detectable.)

To protect against account compromise, we encourage two-factor authentication for all users, as well as send an email notification to users whenever there is a login to their account.

To protect against harms posed by a malicious user who is part of a project, we limit the total number of truly destructive actions that users can take on Atlos. For example, there is no way to irreversibly delete data on Atlos; incidents can be marked as deleted, but they will still be accessible to project owners (e.g., in the “Deleted” tab on the project page, which is accessible to project owners and managers). Note that the inability to truly delete Atlos data presents its own risks and challenges, which are explored below in [Researcher safety](/safety-and-security/risk-model/#researcher-safety).

#### How can our users address this risk?
The responsibility to protect the confidentiality, availability, and integrity of Atlos data primarily rests with ourselves. But our users can take several steps to protect their data security as well:
- Use multi-factor authentication, which makes it significantly harder for attackers to compromise your account.
- Use an anonymous or pseudonymous username, which potentially lessens the consequences of an attacker breaking the confidentiality of our data.
- Pay attention to account login emails from Atlos, and notify the Atlos team if you see an unexpected or suspicious login.
- Periodically backup your Atlos data yourself. While we automatically backup all data on Atlos, we nonetheless encourage you to perform your own backups as well for your investigations. 

#### Implications for our users
In light of the risks associated with using Atlos, we recommend that you:
- Avoid using Atlos for investigations that involve closed-source material. We want the impact of a confidentiality-breaching security incident to be limited in its potential real-world harm. Ideally, no one should be harmed or hurt if all the data in your projects on Atlos were made public. As a result, we strongly recommend against using Atlos for investigations that involve closed-source material.
- Avoid using Atlos using your real name or personal email address if your use of Atlos violates local laws or is politically sensitive. For example, if you are using Atlos to document atrocities committed by your own government, strongly consider using Atlos under a pseudonym (and connecting via a VPN).

### Source material
Source material refers to information uploaded to Atlos as part of an incident. For example, when you archive a web page using Atlos, that page and its associated media (videos, images, etc.) are stored in Atlos as source material.

Source material is distinct from user and investigation material in that it consists of files stored on Amazon AWS S3 (soon Microsoft Azure), rather than in our Postgres database. Our AWS S3 buckets are private.

#### What could go wrong?
As with user and investigation data, it’s helpful to think about the risks to the confidentiality, integrity, and availability of this data.

- **Confidentiality is broken.** To protect the confidentiality of source material, we use strong bucket permissions on AWS S3, and encrypt the data at rest. When serving source material to users in the Atlos interface, the application generates a unique URL containing a cryptographic signature that allows access to the given resource. As a result, if an attacker is able to attain remote code execution control over our server, they would have access to source material (though, for reasons explained below, they would not have the ability to delete source material). Note that we would disclose source material to law enforcement if compelled by a valid legal request. Note that projects can be configured to send all links submitted to Atlos as source material to the [Internet Archive](https://archive.org/). When users opt in to this feature, the contents of all links submitted to a given project will be be publicly available in the Wayback Machine.
- **Integrity is broken.** To protect the integrity of source material, Atlos does not allow users to reupload or directly delete source material; we also have “object versioning” setup on our Amazon S3 bucket to protect source material in the case of an application failure or error, and multi-factor delete protection enabled. Therefore, an attacker would have to gain control over an Atlos core team member’s physical MFA device in order to modify or delete source material. Note that we assume that Amazon AWS itself is secure.
- **Availability is broken.** To protect the availability of source material, we use Amazon AWS S3 for storage, a highly robust file storage service. As noted above, we also have special safeguards in place against deleting source material.

It is also important to note that our automatic archival system is not perfect. While generally robust, our archival system has limitations, and it’s not meant for evidentiary or forensic purposes. For example, our archival system can’t archive pages that require authentication (e.g., private Telegram links); it may miss media on certain pages; and it might sometimes break.

#### How does Atlos address this risk?
In addition to the technical safeguards listed above, Atlos computes a cryptographically secure hash of all source material. This hash is stored as user and investigations data, and is therefore separated from the underlying storage of source material. If source material is altered (e.g., due to an AWS security issue), such alterations would be detectable provided that the Atlos database—which is not stored on Amazon AWS—is not affected.

The Atlos source material interface includes a warning that automatic archival is provided on a best-effort basis, and that it should not be used for evidentiary purposes.

#### How can our users address this risk?
We strongly encourage our users to periodically download critically important media to their own independent storage systems.

#### Implications for our users
If you plan to use Atlos for evidentiary purposes—or require “forensic” archival—you should independently archive your source material.

### Usage information
Usage information refers to audit logs and analytics data that we collect as you use Atlos. For example, we collect product interactions via [Highlight](https://highlight.run), an open source bug monitoring and product analytics tool. We also collect audit log data via a private Slack channel accessible to the Atlos team with a 90 day retention policy.

We collect different usage information for different reasons. For example, we collect redacted product interaction data via Highlight in order to better understand how users are navigating through Atlos and to understand what kind of bugs they’re running into. We also collect audit logs via Slack (under a 90 day retention policy) to create an independent record of user actions that we could cross reference in the event of abuse or a breach.

#### What could go wrong?
- **Confidentiality is broken.** Our upstream service providers could suffer a security incident that reveals private Atlos usage information. In the case of Slack, this would be very damaging; our Slack audit logs include non anonymized usage interactions as well as user IP addresses. (We believe collecting this data is necessary in order to investigate abuse and potential breaches.) In the case of Highlight, a breach could reveal metadata about user accounts (city of origin, device type, etc.), but no direct source material or investigation data. Highlight data makes it possible to determine where in the interface a user has clicked, but not the underlying data they have viewed.
- **Integrity or availability is broken.** If the integrity or availability of our usage information is broken (e.g., an attacker is able to delete our audit logs or otherwise make them inaccessible), we would be less effective at identifying security issues. However, there would be no direct operational impact to our users.

#### How does Atlos address this risk?
We try to collect as little usage information as we responsibly can, and we implement strong security protections for the information we do collect.
- We have a 90 day retention policy on our audit logging Slack channel.
- We restrict our audit logs to the Atlos founders, who each have multi-factor authentication enabled on the account. Non-founding Atlos team members do not have access to this data.
- We have [“strict privacy” mode](https://www.highlight.io/docs/getting-started/client-sdk/replay-configuration/privacy) enabled for Highlight, which prevents actual underlying user and investigation data from being sent to the Highlight platform (which is external to Atlos). In other words, **user and investigation data is not sent to Highlight.**

#### How can our users address this risk?
If you are concerned about your general physical location (as identified by your IP address) being present in our usage data, we strongly encourage you to use a VPN when connecting to Atlos. You may also use a browser extension such as uBlock Origin to disable our product analytics from collecting information about your interactions. However, we believe that neither of these steps are necessary for the majority of our users.

## Researcher safety
We care deeply about protecting the safety and wellbeing of our users. Open source investigations involving visual media can be extremely politically sensitive, potentially putting researchers in danger; they can often lead to vicarious psychological trauma.

#### What could go wrong?
- **Researchers are arrested, persecuted, or otherwise targeted for their work on Atlos.** Human rights investigations often draw the ire of governments, and even citizens. We recognize that investigators, journalists, and citizens may be targeted for their work on Atlos — or perhaps even for using Atlos in the first place.
- **Researchers could experience vicarious trauma (e.g., PTSD) through their work on Atlos.** Often, investigations on Atlos involve a significant amount of highly graphic and traumatic media. The psychological effects of this media are well documented, and often manifest as PTSD, depression, and anxiety. By making it easier to conduct large scale visual investigations, Atlos may indirectly contribute to researchers’ vicarious trauma.
  
#### How does Atlos address this risk?
We take several steps to protect the safety of our users, but we are mindful that there are fundamental limits on our ability to protect researchers.

We encourage researchers who may be **targeted or prosecuted** for their work on Atlos to use a VPN or Tor to connect to our services (we intentionally do not block Tor connections); we also encourage these researchers to sign up under a pseudonym and even pay for Atlos anonymously. (If you would like to pay for Atlos using cash or a cryptocurrency, please email us at [contact@atlos.org](mailto:contact@atlos.org).)

To protect against **vicarious trauma**, Atlos implements a number of safeguards for graphic content. First, all source material on Atlos is displayed in grayscale and muted by default, both of which are [common techniques](https://meedan.com/post/vicarious-trauma-mitigating-graphic-content-in-newsrooms) to reduce the psychological impact of graphic media. Second, graphic source material is hidden behind a warning, preventing researchers from inadvertently viewing graphic content. Third, Atlos applies a visual indicator to sensitive incidents across the entire platform (e.g., highlighting graphic incidents in red inside table view), ensuring that researchers can make an informed decision before opening any graphic incident.

#### How can our users address this risk?
There is no one-size-fits-all approach to safety; everyone’s threat model—and risk tolerance—is different. 

Researchers in **particularly sensitive situations** can protect themselves from being targeted (or prosecuted) for their work on Atlos by following strict operational security guidelines—such as by using Tor, signing up under a pseudonym, paying for Atlos anonymously, and so on. Note that this degree of operational security should also apply to the user’s work beyond Atlos.

We highly recommend that users who may face prosecution or physical danger for their work on Atlos consult a security professional directly for more personalized advice.

Our users can address the risk of **vicarious trauma** by taking frequent breaks from viewing graphic content, being mindful of their emotional wellbeing, taking time to mentally prepare themselves before viewing graphic content, and working with trauma counselors and therapists. Note that these steps are by no means exhaustive; visual investigations can have a significant impact on researchers’ mental health, and there are no “quick fixes” to mitigate these effects.

## Civilian safety
Content on Atlos often depicts civilians, and these civilians are sometimes identifiable. Media on Atlos may therefore pose a risk to the safety of those civilians; for example, a civilian who documents police brutality may face persecution or violence themselves.

While Atlos is intended to be used only for open source data (and projects on Atlos are not public), we recognize that civilians pictured in—or associated with—media on Atlos may not be aware that the media will be used for investigative purposes. We must therefore be mindful of the risks that Atlos (and the investigations it supports) pose to the civilians connected to archived source material.

#### How does Atlos address this risk?
Atlos attempts to protect the safety of civilians pictured in source material added to the platform by 1) enforcing strict data security measures, 2) allowing researchers to explicitly mark incidents as having “Personal Information Visible”, and 3) allowing researchers to hide certain incidents within projects.

#### How can our users address this risk?
Our users can help protect civilian safety by being mindful of what information they upload to Atlos, and what information they choose to share publicly. For example, we strongly encourage users to only work with open source data; moreover, we encourage investigators to limit access to incidents that contain personally identifying information in large investigations.

## Archival robustness
Atlos has a robust archival system built-in to the platform. Given an arbitrary URL—be it from Telegram, Twitter, or elsewhere—Atlos will attempt to create a thorough archive. 

However, Atlos’ archival system operates on a **best-effort basis**. It may miss important media on the page; it may fail unpredictably or intermittently; some features may fail silently. It is important to not treat Atlos’ archival system as infallible.

Similarly, Atlos’ perceptual hashing capabilities are not perfect. (Perceptual hashing is the process by which Atlos identifies duplicate media in a project by examining source material visually.)

Atlos’ archival system is **not “forensic”**, and should not be used for legal evidentiary purposes without supplementation.

#### How does Atlos address this risk?
Atlos addresses the risk of archival failure and inconsistency by:
- continuously monitoring the archival system for failures (which we attempt to promptly address);
- clearly communicating failures in the interface;
- optionally using the Internet Archive’s Wayback Machine as a second independent archival layer (note that if Internet Archive archival is enabled on a project, source material added to Atlos will be available publicly in the Internet Archive);
- noting the limitations of Atlos’ archival system in the interface itself (“Atlos provides best-effort archival. Archives may be incomplete or missing, and should not be relied on for legal evidence.”); and
- relying on existing, well-maintained archival and analysis tools—such as Bellingcat’s [auto-archiver](https://github.com/bellingcat/auto-archiver), [yt-dlp](https://github.com/yt-dlp/yt-dlp), [Selenium](https://www.selenium.dev/), and Thorn’s [perception](https://perception.thorn.engineering/)—to power core functionality.
  
#### How can our users address this risk?
Our users can address the risk of archival failure and inconsistency by supplementing our archival processes with their own. For example, users can connect to our API to read source material and conduct their own independent archives (e.g., using Bellingcat’s [auto-archiver](https://github.com/bellingcat/auto-archiver), [Hunchly](https://www.hunch.ly/), or [Browsertrix Crawler](https://github.com/webrecorder/browsertrix-crawler)). Users interested in applying source material to evidentiary purposes should explore partnering with an organization with deep expertise in legally admissible archival, such as [Mnemonic](https://mnemonic.org/).

## Platform longevity
Atlos is a small non-profit organization. We don’t plan on disappearing any time soon. But we also recognize that times change and projects can come to an end — whether we like it or not.

If we do make the difficult decision to shut down Atlos, we commit to providing all our users with at least six months of notice to export their data and migrate to another platform. (Note that Atlos is an open source project, so there will always be an opportunity for our users to host Atlos themselves.) We will do everything in our power to support a smooth transition off Atlos.

## Conclusion
We take security and safety incredibly seriously—but, like any digital platform, using Atlos carries risk. We hope that this document helps you better understand Atlos’ threat model.

If you have any questions or feedback, please contact us at [contact@atlos.org](mailto:contact@atlos.org).

## Areas for improvement
We welcome feedback and contributions to this risk model. Here are some areas that may warrant additional explanation:
- The precise situations in which we would and would not honor legal requests
- How we protect the integrity of our source code and CI pipelines
- A precise list of Atlos’ vendors and what access those vendors have
