defmodule Platform.Repo do
  use Ecto.Repo,
    otp_app: :platform,
    adapter: Ecto.Adapters.Postgres

  use Quarto,
    maximum_limit: :infinity,
    cursor: Platform.Cursor.SignedCursor,
    include_total_count: false,
    total_count_limit: 1000

  Postgrex.Types.define(
    Platform.Repo.PostgresTypes,
    [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
    json: Jason
  )
end
