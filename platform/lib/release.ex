defmodule Platform.Release do
  @app :platform

  def migrate do
    ensure_apps_ok()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    ensure_apps_ok()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp ensure_apps_ok do
    Application.load(@app)
    Application.ensure_all_started(:ssl)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end
end
