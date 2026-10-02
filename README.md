# WuFengBot

[自行部署](docs/deployment_guide.md) | [许可证](LICENSE)

[![Build](https://github.com/ws126837251/wufeng-bot/actions/workflows/publish.yml/badge.svg?branch=main)](https://github.com/ws126837251/wufeng-bot/actions/workflows/publish.yml)
[![License](https://img.shields.io/github/license/ws126837251/wufeng-bot)](LICENSE)

WuFengBot 是一个面向 Telegram 群组运营的群组管理机器人，支持多个群组分别保存配置，并通过管理后台切换当前控制的群组。

## 功能

- **多群组独立管理**：每个群组单独保存验证、权限、自动化和抽奖设置。
- **入群验证与成员管理**：支持入群验证、审核、权限管理、黑名单和成员同步。
- **消息自动化**：欢迎语、关键词回复、定时消息、违规词拦截和机器人消息清理。
- **抽奖中心**：创建抽奖、关键词报名、开奖、中奖记录，以及可选的邀请助力机制。
- **私聊中转**：用户验证后，可将文字、图片和文件转发给客服，并支持继续转发或停止转发。
- **商品通知**：接收网站商品上架通知，发送图片、文案和 Telegram 操作按钮。
- **管理界面**：提供 Web 管理后台和 Telegram Mini App 控制台。

## 项目结构

- `lib/`：Elixir/Phoenix 后端、Telegram Bot 逻辑和业务模块。
- `console/`：Telegram Mini App 管理控制台。
- `admin/`：Web 管理端前端。
- `member_sync/`：成员同步辅助脚本，凭据从环境变量读取。
- `priv/repo/migrations/`：数据库迁移文件。
- `docs/deployment_guide.md`：部署说明。

## 配置与部署

生产密钥、Bot Token、数据库和运行数据不在仓库中。请复制 `.env.example`，根据自己的环境填写配置后再启动服务。

完整部署步骤请参考：[部署说明](docs/deployment_guide.md)

开发环境的 Compose 配置位于：

- `docker-compose.dev.yml`
- `docker-compose.prod.yml`
- `docker-compose.yml`

## 安全说明

请勿把 `.env`、数据库备份、Telegram 会话文件或用户数据提交到 Git。公开部署时必须设置独立的数据库密码、Web 密钥和 Bot Token。

## 说明

本项目是在 PolicrMini 基础上的二次开发版本，保留原项目的许可证和相关技术归属。项目中的生产配置、用户数据和凭据不属于开源内容。
