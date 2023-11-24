defmodule PlatformWeb.Router do
  use PlatformWeb, :router

  import PlatformWeb.UserAuth
  import PlatformWeb.APIAuth
  alias PlatformWeb.MountHelperLive

  pipeline :browser do
    plug(RemoteIp)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {PlatformWeb.LayoutView, :root})
    plug(:protect_from_forgery)

    plug(:put_secure_browser_headers, %{
      # TODO: There are opportunities to make this content security policy stricter (specifically by adding
      # `default-src 'none'` and removing cdn.jsdelivr.net); this is an opportunity for future improvement. To
      # quote Sobelow, just about any CSP is better than the default (no CSP at all!).
      "content-security-policy" =>
        "object-src 'none'; script-src 'self' js.hcaptcha.com unpkg.com static.highlight.io 'unsafe-eval' blob:; base-uri 'none';"
    })

    plug(:fetch_current_user)
  end

  pipeline :app do
    plug(:put_layout, {PlatformWeb.LayoutView, "interstitial.html"})
  end

  pipeline :interstitial do
    plug(:put_layout, {PlatformWeb.LayoutView, "interstitial.html"})
  end

  pipeline :interstitial_minimal do
    plug(:put_layout, {PlatformWeb.LayoutView, "interstitial_minimal.html"})
  end

  pipeline :api do
    plug(RemoteIp)
    plug(:accepts, ["json"])
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: PlatformWeb.Telemetry)
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through(:browser)

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  scope "/api", PlatformWeb do
    pipe_through([:api, :check_api_token])

    scope "/v1" do
      pipe_through([:require_legacy_token])

      get("/media_versions", APIV1Controller, :media_versions)
      get("/media", APIV1Controller, :media)
    end

    scope "/v2" do
      pipe_through([:require_project_scoped_token])

      get("/source_material", APIV2Controller, :source_material)
      get("/incidents", APIV2Controller, :incidents)
      post("/add_comment/:slug", APIV2Controller, :add_comment)
      post("/update/:slug/:attribute", APIV2Controller, :update)
    end
  end

  scope "/", PlatformWeb do
    get("/health_check", HealthCheckController, :index)
    # Will return non-200 status code after uptime is > 12 hours
    get("/health_check/exp", HealthCheckController, :exp)
  end

  scope "/spi", PlatformWeb do
    pipe_through([:browser, :require_authenticated_user])

    get("/users", SPIController, :user_search)
  end

  scope "/", PlatformWeb do
    pipe_through([:browser, :interstitial])
    get("/users/suspended", UserRegistrationController, :suspended)
    get("/users/no_access", UserRegistrationController, :no_access)
  end

  scope "/", PlatformWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated, :interstitial])

    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)

    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/log_in/mfa", UserSessionController, :new_mfa)
    post("/users/log_in/mfa", UserSessionController, :create_mfa)

    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
    put("/users/reset_password/:token", UserResetPasswordController, :update)
  end

  scope "/", PlatformWeb do
    pipe_through([:browser, :interstitial])

    delete("/users/log_out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :edit)
    post("/users/confirm/:token", UserConfirmationController, :update)
  end

  scope "/", PlatformWeb do
    pipe_through([:browser, :require_authenticated_user, :interstitial_minimal])

    get("/users/onboarding", UserRegistrationController, :onboarding)
  end

  scope "/", PlatformWeb do
    pipe_through([:browser, :require_authenticated_user, :app])

    # Redirect /map to avoid breaking old links
    get("/map", PageController, :index)
    get("/", PageController, :index)

    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)

    post("/export/incidents", ExportController, :create_csv_export)
    post("/export/full", ExportController, :create_full_export)

    live_session :default, on_mount: {MountHelperLive, :authenticated} do
      live("/settings", SettingsLive)
      live("/settings/mfa", SettingsLive.MFALive)

      live("/home", HomeLive.Index, :index)

      live("/new", NewLive)

      live("/incidents", MediaLive.Index)

      live("/incidents/:slug", MediaLive.Show, :show)
      live("/incidents/:slug/card", MediaLive.Card)
      live("/incidents/:slug/update/:attribute", MediaLive.Show, :edit)
      live("/incidents/:slug/history/:attribute", MediaLive.Show, :history)
      live("/incidents/:slug/upload", MediaLive.Show, :upload)
      live("/incidents/:slug/upload/merge", MediaLive.Show, :merge)
      live("/incidents/:slug/upload/copy", MediaLive.Show, :copy)
      live("/incidents/:slug/auto_metadata", MediaLive.Show, :auto_metadata)
      live("/incidents/:slug/detail/:scoped_id", MediaLive.Show, :media_version_detail)

      live("/projects", ProjectsLive.Index, :index)
      live("/projects/new", ProjectsLive.Index, :new)
      live("/projects/:id", ProjectsLive.Show, :overview)
      live("/projects/:id/map", ProjectsLive.Show, :map)
      live("/projects/:id/edit", ProjectsLive.Show, :edit)
      live("/projects/:id/access", ProjectsLive.Show, :access)
      live("/projects/:id/deleted", ProjectsLive.Show, :deleted)
      live("/projects/:id/queue", ProjectsLive.Show, :queue)

      live("/profile/:username", ProfilesLive.Show, :show)
      live("/profile/:username/assignments", ProfilesLive.Show, :assignments)
      live("/profile/:username/subscriptions", ProfilesLive.Show, :subscriptions)
      live("/profile/:username/edited", ProfilesLive.Show, :edited)
      live("/profile/:username/admin", ProfilesLive.Show, :admin)
      live("/profile/:username/admin/edit", ProfilesLive.Show, :admin_edit)

      live("/notifications", NotificationsLive)
    end

    live_session :admin, on_mount: {MountHelperLive, :admin} do
      live("/adminland/", AdminlandLive.Index, :activity)
      live("/adminland/users", AdminlandLive.Index, :users)
      live("/adminland/deleted", AdminlandLive.Index, :deleted)
      live("/adminland/activity", AdminlandLive.Index, :activity)
      live("/adminland/announcements", AdminlandLive.Index, :announcements)
      live("/adminland/security", AdminlandLive.Index, :security)
      live("/adminland/security/update", AdminlandLive.Index, :security_mode_create)
      live("/adminland/api", AdminlandLive.Index, :api)
      live("/adminland/api/new", AdminlandLive.Index, :api_new)
    end
  end
end
