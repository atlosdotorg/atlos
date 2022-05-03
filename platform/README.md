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

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
