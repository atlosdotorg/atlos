# Platform

To start your Phoenix server:

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Environment Variables

- `S3_BUCKET` — the primary S3 bucket to use for content
- `AWS_REGION` — the AWS region
- `AWS_ACCESS_KEY_ID` — the AWS access key id
- `AWS_SECRET_ACCESS_KEY` — the AWS access secret
- `APPSIGNAL_PUSH_KEY` — the AppSignal push key
- `APPSIGNAL_APP_ENV` — `dev`, `staging`, or `prod` (how we disambiguate environments in AppSignal)
- `SLACK_AUDITING_WEBHOOK` — Slack webhook for audit events
- `HCAPTCHA_SITE_KEY` — hCaptcha site key
- `HCAPTCHA_SECRET` — hCaptcha secret
- `ENABLE_CAPTCHAS` — captchas are _checked_ if `true` (default false for development)
- `WATERMARK_FONT_PATH` — path to the font to use in watermarks
- `RULES_LINK` — link to use for the rules (note that the ToS are not configurable)
- `INSTANCE_NAME` — user-facing instance name (appears in footer and below logo; not shown if empty)
- `SPN_ARCHIVE_API_KEY` — API key for the Internet Archive [SPN API](https://docs.google.com/document/d/1Nsv52MvSjbLb2PCpHlat0gkzw0EvtSgpKHu4mk0MnrA/edit#) (if provided, Atlos will submit all links to the Internet Archive for persistent archival; key expected in the form `myaccesskey:mysecret`)
- `COMMUNITY_DISCORD_LINK` — link to the community Discord server (shown in onboarding and in Settings)
- `CUSTOM_ATTRIBUTE_OPTIONS` — JSON object of custom _additional_ attribute options; e.g., `{"type": ["Civilian Harm"]}`
- `AUTOTAG_USER_INCIDENTS` — JSON object of tags to apply to incidents created by non-privileged users; e.g., `["Volunteer"]`

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
