defmodule PolicrMiniWeb.Router do
  use PolicrMiniWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :console_v2_browser do
    plug :allow_console_webapp_embedding
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin_v2 do
    plug PolicrMiniWeb.AdminV2.TokenAuth, from: :page
  end

  pipeline :admin_v2_api do
    plug :accepts, ["json"]
    plug PolicrMiniWeb.AdminV2.TokenAuth, from: :api
  end

  pipeline :console_v2_api do
    plug :accepts, ["json"]
    plug PolicrMiniWeb.ConsoleV2.TMAAuth, from: :api
  end

  scope "/api/v1", PolicrMiniWeb.API.V1 do
    pipe_through :api
    get "/totals", IndexController, :totals
  end

  scope "/admin/v2/api", PolicrMiniWeb.AdminV2.API do
    pipe_through [:admin_v2_api]
    get "/", PageController, :index
    get "/profile", ProfileController, :index
    get "/stats", StatsController, :index
    get "/customize", CustomizeController, :index
    get "/management", PageController, :management
    get "/assets", PageController, :assets
    get "/tasks", PageController, :tasks
    put "/schemes/default", SchemeController, :update_default
    post "/provider/upload", ProviderController, :upload
    delete "/provider/uploaded", ProviderController, :delete
    put "/provider/deploy", ProviderController, :deploy
    put "/chats/:id/sync", ChatController, :sync
    put "/chats/:id/leave", ChatController, :leave
    post "/bees/reset_stats", BeeController, :reset_stats
    get "/term", TermController, :show
    put "/term", TermController, :save
    delete "/term", TermController, :delete
    post "/term/preview", TermController, :preview
    get "/stats/query", StatsController, :query
  end

  scope "/admin/v2", PolicrMiniWeb.AdminV2 do
    pipe_through [:browser, :admin_v2]
    get "/*path", PageController, :home
  end

  scope "/console/v2/api", PolicrMiniWeb.ConsoleV2.API do
    pipe_through [:console_v2_api]
    get "/users/me", UserController, :me
    get "/chats", ChatController, :index
    post "/chats/:id/copy-settings", ChatController, :copy_settings
    put "/chats/:id/takeover", ChatController, :takeover
    post "/chats/:id/leave", ChatController, :leave
    get "/chats/:id/stats", ChatController, :stats
    get "/chats/:id/health", ChatController, :health
    get "/chats/:id/scheme", ChatController, :scheme
    get "/chats/:id/customs", ChatController, :customs
    get "/chats/:id/verifications", ChatController, :verifications
    get "/chats/:id/operations", ChatController, :operations
    get "/chats/:chat_id/permissions", PermissionController, :index
    put "/chats/:chat_id/permissions/:user_id", PermissionController, :update
    get "/chats/:id/members", MemberController, :index
    get "/chats/:id/member-sync", MemberController, :sync_status
    post "/chats/:id/member-sync", MemberController, :sync
    get "/chats/:id/member-actions", MemberController, :actions
    get "/chats/:id/member-blacklist", MemberController, :blacklist
    post "/chats/:id/members/:user_id/kick", MemberController, :kick
    post "/chats/:id/members/:user_id/blacklist", MemberController, :kick
    post "/chats/:id/member-blacklist/:user_id/unblock", MemberController, :unblock
    put "/schemes/:id", SchemeController, :update
    put "/verifications/:id/kill", VerificationController, :kill
    post "/customs", CustomController, :add
    put "/customs/:id", CustomController, :update
    delete "/customs/:id", CustomController, :delete
    get "/chats/:id/automation", AutomationController, :show
    put "/chats/:id/automation", AutomationController, :update
    get "/chats/:id/forbidden-words", AutomationController, :forbidden_words
    post "/chats/:id/forbidden-words", AutomationController, :add_forbidden_word
    delete "/chats/:id/forbidden-words/:word_id", AutomationController, :delete_forbidden_word
    get "/chats/:id/keyword-replies", AutomationController, :keyword_replies
    post "/chats/:id/keyword-replies", AutomationController, :add_keyword_reply
    put "/chats/:id/keyword-replies/:reply_id", AutomationController, :update_keyword_reply
    delete "/chats/:id/keyword-replies/:reply_id", AutomationController, :delete_keyword_reply
    get "/chats/:id/forbidden-whitelist", AutomationController, :forbidden_whitelist
    post "/chats/:id/forbidden-whitelist", AutomationController, :add_forbidden_whitelist

    delete "/chats/:id/forbidden-whitelist/:rule_id",
           AutomationController,
           :delete_forbidden_whitelist

    get "/chats/:id/moderation-events", AutomationController, :moderation_events
    get "/chats/:id/schedules", AutomationController, :schedules
    post "/chats/:id/schedules", AutomationController, :add_schedule
    put "/chats/:id/schedules/:schedule_id", AutomationController, :update_schedule
    post "/chats/:id/schedules/:schedule_id/test", AutomationController, :test_schedule
    delete "/chats/:id/schedules/:schedule_id", AutomationController, :delete_schedule
    get "/chats/:id/lotteries", LotteryController, :index
    get "/chats/:id/lotteries/:lottery_id/entries", LotteryController, :entries
    get "/chats/:id/lotteries/:lottery_id/audit", LotteryController, :audit
    post "/chats/:id/lotteries", LotteryController, :create
    post "/chats/:id/lotteries/:lottery_id/draw", LotteryController, :draw
    post "/chats/:id/lotteries/:lottery_id/cancel", LotteryController, :cancel
  end

  scope "/console/v2", PolicrMiniWeb.ConsoleV2 do
    pipe_through [:browser, :console_v2_browser]
    get "/bot/photo", PageController, :bot_photo
    get "/:id/photo", PageController, :photo
    get "/*path", PageController, :home
  end

  scope "/", PolicrMiniWeb do
    pipe_through :browser
    get "/", PageController, :index
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp allow_console_webapp_embedding(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> delete_resp_header("cross-origin-window-policy")
    |> delete_resp_header("cross-origin-opener-policy")
  end
end
