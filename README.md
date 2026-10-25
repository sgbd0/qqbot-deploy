# AstrBot + NapCat QQ 机器人（Render 免费档）

一个 Docker 容器里同时跑 AstrBot（机器人大脑）和 NapCat（QQ 协议端）。

## 架构

- **AstrBot**：官方镜像 `soulter/astrbot`，管理面板 6185，OneBot WS 6199
- **NapCat**：来自官方镜像 `mlikiowa/napcat-docker`（含 QQ NT），首次启动时通过
  `MODE=reverse_ws` + `ONEBOT_URL=ws://127.0.0.1:6199/ws` 自动连上 AstrBot
- **对外端口**：Render 的 `$PORT` 由 socat 转发到 AstrBot 面板（6185）

## 数据持久化（Render 免费档无磁盘）

- 每 15 分钟把 `/AstrBot/data`、`/app/napcat/config`、`/app/.config/QQ`
  （含 QQ 登录态）提交推送到 GitHub 私有仓库
- 环境变量：`GITHUB_REPO`（如 `user/astrbot-qq-backup`）、`GITHUB_PAT`（repo 权限）
- 容器重启/重建后启动脚本自动从备份仓库恢复

## 保活

Render 免费档 15 分钟无流量休眠。`.github/workflows/keepalive.yml` 每 6 分钟
ping 一次服务地址；在仓库 Secrets 中配置 `RENDER_URL`。

## 首次使用

1. Render → New → Blueprint → 选本仓库 → 填 `GITHUB_REPO` / `GITHUB_PAT`
2. 构建完成后打开服务 URL 进入 AstrBot 面板（初始密码在 Render 日志搜 `Initial password`）
3. QQ 扫码登录：NapCat 启动后会在**运行日志**里输出二维码链接，手机 QQ 打开该链接确认即可
