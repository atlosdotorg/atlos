defmodule PlatformWeb.ExportController do
  require Logger
  use PlatformWeb, :controller

  alias Platform.Material
  alias Material.Attribute
  alias Material.MediaSearch
  alias Material.Media
  alias PlatformWeb.HTTPDownload
  alias Platform.Permissions
  alias Platform.Projects
  alias Platform.Utils
  alias Platform.Uploads.ExportFile

  def schedule_csv_export(user, params \\ nil) do
    %{
      "user_id" => user.id,
      "params" => params,
      "type" => "csv"
    }
    |> Platform.Workers.ExportWorker.new()
    |> Oban.insert!()

    :ok
  end

  def schedule_full_export(user, params \\ nil) do
    %{
      "user_id" => user.id,
      "params" => params,
      "type" => "full"
    }
    |> Platform.Workers.ExportWorker.new()
    |> Oban.insert!()

    :ok
  end

  def create_backup_codes_export(conn, %{"token" => tok}) do
    with {:ok, %{:uid => uid}} <-
           Phoenix.Token.verify(PlatformWeb.Endpoint, "backup_codes_export", tok, max_age: 3600),
         true <- uid == conn.assigns.current_user.id do
      user = conn.assigns.current_user

      codes =
        user.recovery_codes
        |> Enum.map(&Utils.format_recovery_code(&1))

      path = Temp.path!(suffix: "atlos-backup-codes.txt")
      file = File.open!(path, [:write, :utf8])

      file
      |> IO.write("""
      Atlos Backup Codes

      #{1..length(codes) |> Enum.zip(codes) |> Enum.map(fn {idx, code} -> "#{idx}. #{code}" end) |> Enum.join("\n")}

      (#{user.email})

      - You can only use each code once.
      - Generate more at Account > Manage Account > Multi-factor auth
      - Generated at #{DateTime.utc_now()}
      """)

      :ok = File.close(file)
      send_download(conn, {:file, path}, filename: "atlos-backup-codes.txt")
    else
      _ -> raise PlatformWeb.Errors.Unauthorized, "Token Invalid or Not Found"
    end
  end
end
