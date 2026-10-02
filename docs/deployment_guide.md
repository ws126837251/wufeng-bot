# WuFengBot 部署说明

本文说明如何从公开仓库使用 Docker Compose 部署 WuFengBot 当前源码。仓库包含群管理、消息自动化、抽奖、客服留言中转和商品通知转发；具体功能和实现范围见 [README](../README.md)。生产凭据、数据库和 Telegram 会话保存在部署环境中，不提交到 Git。

## 前提条件

- Linux 服务器或其他支持 Docker 的主机
- Docker Engine 和 Docker Compose v2
- 一个由 BotFather 创建的 Telegram Bot
- 如果需要成员同步或本地 Bot API：Telegram API ID 和 API Hash
- 如果通过域名访问后台：域名和反向代理（可选）

群管理使用 Telegram 超级群，将机器人加入并按功能授予删除消息、限制成员、邀请用户或置顶权限。频道登记用于商品通知转发，需授予发布消息权限；群组的入群验证和成员处罚功能不套用到频道。

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

成员同步受 Telegram 权限和返回数量限制，未拉取完整名单时会记录失败，不作为完整同步结果导入。

商品网站心跳、统计和其他可选服务可按需要配置。不要把真实 Token、密码或数据库连接串写入 `.env.example`。

## 启动服务

源码部署使用根目录的 `docker-compose.yml`，它会根据当前源码构建 WuFengBot 镜像：

仓库中的 `docker-compose.prod.yml` 仍引用上游 `gramoss/policr-mini:nightly` 镜像。需要本仓库新增功能时，使用下面的源码构建命令。

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f server
```

生产配置启用运行时迁移时，服务会在启动阶段执行数据库迁移。确认服务日志无迁移错误、Bot 开始 polling，或 webhook 正常接收更新后，再打开控制台。

## 访问后台

如果 `POLICR_MINI_WEB_PORT` 绑定在本机，建议通过 Nginx、Caddy 或 Cloudflare Tunnel 反向代理到该端口，并确保代理地址与 `POLICR_MINI_WEB_URL_BASE` 一致。

日常群管理面板为 `/console/v2`。在机器人私聊中发送 `/start`，通过对应 Mini App 按钮进入；直接在普通浏览器打开页面，可能因缺少 Telegram 身份而无法访问群管理 API。主面板提供工作台、安全、消息、成员、抽奖、记录、权限和自定义验证入口。原 Web 管理端 `/admin/v2` 仍保留。

不要直接把带有管理后台的端口暴露到公网，除非已经配置好 HTTPS、访问控制和主机防火墙。

## 配置可选功能

### 抽奖邀请与报名消息清理

在当前群的“抽奖中心”创建活动时，可按场次设置“允许邀请好友提高中奖权重”。关闭后邀请按钮和邀请链接均不生效。填写参与关键词后，可设置“成功报名后自动删除成员回复”及删除延时。

### 客服留言入口

`POLICR_MINI_BOT_OWNER_ID` 是客服接收账号。该账号先私聊启动机器人，并可发送 `/relay` 开启公开联系入口；访客点击“联系客服（无法私聊请点击）”或发送 `/relay` 后建立中转会话。访客发送的文字、图片和文件会转给客服，同时标注发送者身份。

访客可点击“继续转发 / 停止转发”；客服账号发送 `/relay stop` 会关闭公开入口及全部访客中转。当前实现提供访客留言转发，未实现客服回复回传或独立验证码挑战。

### 网站商品转发

商品上架通知的图片、文案和按钮由网站端生成。网站需使用与 WuFengBot 相同的 Bot，并在通知的内联按钮中设置 `callback_data: "broadcast:v1:open"`。机器人收到回调后，在私聊中提供群组或频道选择，并通过 `copyMessage` 复制包含图片的原消息。

机器人需要能访问原消息，且目标已登记在当前账号可访问的群组/频道列表中，并具备对应发送权限。

Dujiao 配置读取和心跳可选，在 `.env` 中填写以下变量后由根目录 Compose 传入：

```dotenv
POLICR_MINI_DUJIAO_BASE_URL=
POLICR_MINI_DUJIAO_CHANNEL_KEY=
POLICR_MINI_DUJIAO_CHANNEL_SECRET=
POLICR_MINI_DUJIAO_HEARTBEAT_INTERVAL_MS=30000
POLICR_MINI_DUJIAO_BOT_VERSION=wufeng-bot
```

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
