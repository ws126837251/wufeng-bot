# WuFengBot 部署说明

本文说明如何从公开仓库使用 Docker Compose 部署 WuFengBot。生产密钥、数据库和 Telegram 会话只保存在服务器的 `.env` 和运行数据目录中，不提交到 Git。

## 前提条件

- Linux 服务器或其他支持 Docker 的主机
- Docker Engine 和 Docker Compose v2
- 一个由 BotFather 创建的 Telegram Bot
- 如果需要成员同步或本地 Bot API：Telegram API ID 和 API Hash
- 如果通过域名访问后台：域名和反向代理（可选）

将机器人加入需要管理的群组，并按功能授予删除消息、限制成员、邀请用户等必要权限。

## 获取源码

```bash
git clone https://github.com/ws126837251/wufeng-bot.git
cd wufeng-bot
cp .env.example .env
```

Windows PowerShell 可以使用：

```powershell
Copy-Item .env.example .env
```

## 配置环境变量

编辑 `.env`，至少填写以下变量：

```dotenv
POLICR_MINI_DATABASE_PASSWORD=生成一个新的数据库密码
POLICR_MINI_DATABASE_POOL_SIZE=10
POLICR_MINI_INFLUX_PASSWORD=生成一个新的时序数据库密码
POLICR_MINI_INFLUX_TOKEN=生成一个新的时序数据库令牌
POLICR_MINI_WEB_PORT=8080
POLICR_MINI_WEB_SECRET_KEY_BASE=生成一个长度足够的随机密钥
POLICR_MINI_WEB_URL_BASE=https://你的后台域名
POLICR_MINI_BOT_TOKEN=BotFather 提供的 Token
POLICR_MINI_BOT_OWNER_ID=你的 Telegram 数字用户 ID
POLICR_MINI_BOT_WORK_MODE=polling
POLICR_MINI_BOT_API_BASE_URL=
POLICR_MINI_BOT_WEBHOOK_URL=
POLICR_MINI_BOT_WEBHOOK_SERVER_PORT=
POLICR_MINI_BOT_AUTO_GEN_COMMANDS=false
```

如果启用成员同步或本地 Telegram Bot API，还需要填写：

```dotenv
TELEGRAM_API_ID=Telegram API ID
TELEGRAM_API_HASH=Telegram API Hash
```

商品网站心跳、统计和其他可选服务使用的变量可以先留空；对应功能启用前再填写。不要把真实 Token、密码或数据库连接串写入 `.env.example`。

## 启动服务

源码部署使用根目录的 `docker-compose.yml`，它会根据当前源码构建 WuFengBot 镜像：

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f server
```

首次启动时，服务会自动执行必要的数据库迁移。看到 Bot 开始 polling，或 webhook 服务正常监听后即可进入后台。

## 访问后台

如果 `POLICR_MINI_WEB_PORT` 绑定在本机，建议通过 Nginx、Caddy 或 Cloudflare Tunnel 反向代理到该端口，并确保代理地址与 `POLICR_MINI_WEB_URL_BASE` 一致。

不要直接把带有管理后台的端口暴露到公网，除非已经配置好 HTTPS、访问控制和主机防火墙。

## 更新与停止

```bash
git pull
docker compose up -d --build
docker compose logs -f server
```

停止服务：

```bash
docker compose down
```

只要保留 `_data/`、`_member_sync/`、`dumps/`、`shared_assets/` 和 `albums/`，重新构建镜像不会删除数据库和运行数据。上述目录均已加入 `.gitignore`，不要手动提交到公开仓库。

## 安全与备份

- `.env` 只保存在服务器，不上传 GitHub。
- Bot Token、Telegram API Hash、数据库密码和 Web 密钥应分别生成，不能复用。
- 数据库备份应放在仓库目录之外或 `dumps/` 中，并限制文件权限。
- 如果任何凭据曾经进入 Git 历史，必须先撤销并重新生成，再继续部署。

## 开发环境

开发依赖可以单独启动：

```bash
docker compose -f docker-compose.dev.yml up -d
```

后端和前端依赖、测试命令请以 `mix.exs`、`admin/package.json` 和 `console/package.json` 为准。
