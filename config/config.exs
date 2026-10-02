# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the application version
config :policr_mini, version: Mix.Project.config()[:version]

config :policr_mini,
  ecto_repos: [PolicrMini.Repo],
  opts: []

# Configures the endpoint
config :policr_mini, PolicrMiniWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base:
    System.get_env("POLICR_MINI_WEB_SECRET_KEY_BASE") || String.duplicate("0", 64),
  render_errors: [view: PolicrMiniWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PolicrMini.PubSub,
  live_view: [
    signing_salt:
      System.get_env("POLICR_MINI_LIVE_VIEW_SIGNING_SALT") || "dev-signing-salt"
  ]

config :canary,
  repo: PolicrMini.Repo,
  current_user: :user,
  unauthorized_handler: {PolicrMiniWeb.ConsoleV2.ControllerHelper, :resp_forbidden}

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :policr_mini, PolicrMini.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# 配置网格验证
config :policr_mini, PolicrMiniBot.GridCAPTCHA,
  # 个体图片宽度
  indi_width: 180,
  # 个体图片高度
  indi_height: 120,
  # 水印字体
  watermark_font_family: "Lato"

# 配置机器人
config :policr_mini, PolicrMiniBot,
  auto_gen_commands: false,
  mosaic_method: :spoiler

# 配置 Telegex 的适配器
config :telegex,
  caller_adapter: {Finch, [receive_timeout: 5 * 1000]},
  hook_adapter: Cowboy

# 配置根链接
config :policr_mini, PolicrMiniWeb,
  root_url: System.get_env("POLICR_MINI_WEB_URL_BASE") || "http://localhost:4000"

# 配置 Capinde
config :policr_mini, Capinde,
  base_url: System.get_env("POLICR_MINI_CAPINDE_BASE_URL") || "http://localhost:8080"

# 任务调度配置
config :policr_mini, PolicrMiniBot.Scheduler,
  jobs: [
    # 修正过期验证，每 5 分钟。
    expired_check: [
      schedule: "*/5 * * * *",
      task: {PolicrMiniBot.Runner.ExpiredFixer, :run, []}
    ],
    # 恢复到期的临时限制和封禁，每分钟检查一次，服务重启后仍可继续。
    verification_release_check: [
      schedule: "* * * * *",
      task: {PolicrMiniBot.Runner.VerificationReleaseFixer, :run, []}
    ],
    # 非破坏性权限巡检，每 30 分钟。仅记录问题，绝不自动退群或取消接管。
    permission_audit: [
      schedule: "*/30 * * * *",
      task: {PolicrMiniBot.Runner.PermissionAuditor, :run, []}
    ],
    # 每天同步一次接管群的完整成员名单。
    member_sync: [
      schedule: "17 3 * * *",
      task: {PolicrMiniBot.Runner.MemberSyncRunner, :run, []}
    ],
    # 重试尚未成功写入 Telegram 的永久黑名单，每 5 分钟。
    blacklist_enforcement: [
      schedule: "*/5 * * * *",
      task: {PolicrMiniBot.Runner.BlacklistEnforcer, :run, []}
    ],
    # 已离开检查，每日。
    left_check: [
      schedule: "@daily",
      task: {PolicrMiniBot.Runner.LeftChecker, :run, []}
    ]
  ]

# 配置默认语言
config :policr_mini, PolicrMiniWeb.Gettext, default_locale: "zh"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:honeycomb, :request_id, :chat_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
