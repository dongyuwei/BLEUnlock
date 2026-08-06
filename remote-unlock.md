# Remote Unlock 远程解锁（prototype 原型功能）

> 中英双语文档 / Bilingual documentation (中文 / English)

---

## 简介 / Overview

**中文**：一个原型功能：当 Mac 锁定（锁屏）时，通过手机浏览器（经 Tailscale 连接）批准解锁，Mac 会自动输入登录密码。当前不需要 Android/iOS App。

**English**: A prototype feature: when your Mac is locked, approve it from a browser on your phone (over Tailscale) and it types your login password to unlock. No Android/iOS app is required yet.

---

## 工作原理 / How it works

**中文**：
- Mac 运行一个轻量本地 HTTP 服务（POSIX socket 实现，无第三方依赖），默认端口 `8123`。
- 手机通过 Tailscale 访问该服务（Android/iOS 任意浏览器均可）。
- 当 Mac 锁定时，页面显示「批准解锁」按钮；点击后 Mac 唤醒屏幕、必要时退出屏保，并从自己的 Keychain 读取密码自动输入。
- **密码绝不离开 Mac**——手机只发送批准信号。

**English**:
- The Mac runs a small local HTTP server (POSIX sockets, no third-party dependencies) on port `8123` by default.
- Your phone connects to it through Tailscale (any browser, Android or iOS).
- When the Mac is locked, the page shows an **approve** button. Tapping it makes the Mac wake the display, exit the screensaver if needed, and type the login password from its own Keychain.
- **The password never leaves the Mac** — the phone only sends an approve signal.

---

## 安全模型 / Security model

| 项目 Item | 说明 Description |
|---|---|
| 来源限制 Source restriction | 只接受 Tailscale CGNAT 网段 `100.64.0.0/10` 或 `localhost` 的请求，其余返回 `403` / Only accepts requests from Tailscale CGNAT (`100.64.0.0/10`) or `localhost`; everything else gets `403` |
| Token 认证 Token auth | 6 位数字 token；`/status`、`/approve`、`/deny` 必须携带，错误或缺失返回 `401` / A 6-digit numeric token is required for `/status`, `/approve`, `/deny`; wrong or missing tokens get `401` |
| 页面记忆 Page memory | 页面首次输入后保存在浏览器 `localStorage` / The page remembers it in `localStorage` after first entry |
| 失败限速 Rate limiting | 连续 5 次 token 失败后锁定 60 秒（返回 429），每次失败响应延迟 1 秒，成功解锁后重置 / After 5 consecutive token failures, requests are blocked for 60s (HTTP 429); each failed attempt is delayed 1s; counters reset on success |
| Token 存储 Token storage | 明文存于 `UserDefaults`（`~/Library/Preferences/jp.sone.BLEUnlock.plist`）— 可接受，因为能读本机文件的人本就可解锁 Mac / Stored in plaintext in `UserDefaults`; acceptable since anyone with local file access could unlock the Mac anyway |

---

## 端点 / Endpoints

| Method | Path | 说明 Description |
|---|---|---|
| GET | `/` | 解锁页面（浏览器 UI）/ Unlock page |
| GET | `/status` | JSON：`{ "locked": bool, "mac": "...", "now": ... }` |
| POST | `/approve` | 批准解锁（触发输入密码）/ Approve unlock |
| POST | `/deny` | 拒绝 / Deny |

Token 可通过 `?token=123456` 查询参数或 `X-Auth-Token` 请求头传递。
Token can be passed as `?token=123456` query parameter or `X-Auth-Token` header.

---

## 使用步骤 / Setup

```sh
# 首次构建并启动 / build (first time) and run
./start.sh --build
# 或直接启动（会自动杀掉旧实例）/ or just run (kills any existing instance first)
./start.sh
```

1. **菜单栏** → **Remote Unlock** → 勾选 **Enable Remote Unlock**。子菜单显示 URL（`http://<tailscale-ip>:8123/`）和当前 token。
   **Menu bar** → **Remote Unlock** → enable **Enable Remote Unlock**. The submenu shows the URL (`http://<tailscale-ip>:8123/`) and the current token.
2. 设置一次登录密码：菜单 → **Set Password…**（存入 Keychain）。
   Set your login password once: menu → **Set Password…** (stored in Keychain).
3. 手机（已连接 Tailscale）浏览器打开该 URL，输入 6 位 token。
   On your phone (connected to Tailscale), open the URL in a browser and enter the 6-digit token.
4. 锁定 Mac（合盖 / 睡眠 / Ctrl+Cmd+Q）→ 手机页面变 🔒 显示「批准解锁」→ 点击后 Mac 自动输入密码解锁。
   Lock the Mac (close lid / sleep / Ctrl+Cmd+Q). The phone page turns 🔒 with an **approve** button. Tap it and the Mac types the password and unlocks.

日志写入 `~/Library/Logs/BLEUnlock/bleunlock.log`。
Logs are written to `~/Library/Logs/BLEUnlock/bleunlock.log`.

---

## Tailscale Funnel 公网访问 / Public access via Tailscale Funnel

**中文**：**默认禁用**（考虑到公网暴露的风险）。在 Remote Unlock 子菜单勾选 **Enable Funnel (public URL)** 后，app 执行 `tailscale funnel --bg <port>` 把服务发布为公网 HTTPS 地址（例如 `https://yuweim3max.taildfb994.ts.net`）并显示在菜单中。取消勾选即关闭。手机**不需要安装 Tailscale**，浏览器直接访问该地址即可。

**English**: **Disabled by default** (public exposure risk). After checking **Enable Funnel (public URL)** in the Remote Unlock submenu, the app runs `tailscale funnel --bg <port>`, publishing the service at a public HTTPS URL (e.g. `https://yuweim3max.taildfb994.ts.net`) shown in the menu. Unchecking turns it off. Your phone does **not** need Tailscale installed — just open the URL in a browser.

### 前置条件 / Prerequisites

- `tailscale` CLI 可用（`/usr/local/bin/tailscale`、`/opt/homebrew/bin/tailscale` 或 `/Applications/Tailscale.app/Contents/MacOS/Tailscale`）
  The `tailscale` CLI must be available at one of the standard locations.
- 已登录 Tailscale 且账户已启用 Funnel（首次需在 Tailscale 控制台开启 Funnel 功能）
  Signed in to Tailscale, and Funnel enabled for the account (enable once in the admin console).

### 注意事项 / Notes

- **必须使用 `--bg`（后台）模式**：`tailscale funnel <port>` 前台模式的配置随命令退出而失效。app 内部使用 `--bg` 持久化。
  **`--bg` (background) mode is required**: plain `tailscale funnel <port>` runs in the foreground and its config disappears when the command exits. The app uses `--bg` for persistence.
- **启动时清理**：若 Funnel 处于禁用状态而 tailscaled 里残留着指向 8123 的旧配置，app 启动时会自动关闭它（只清理指向本 app 端口的配置，不影响你手动配置的其他端口）。
  **Startup cleanup**: if Funnel is disabled but tailscaled still has a leftover config proxying our port, the app closes it on start (only configs pointing to this app's port, never other ports).
- **速度**：Funnel 流量必经 Tailscale 云中继，实测单次请求约 2–3.5s（中国网络 → 海外边缘节点的双程延迟），属正常。对延迟敏感时可换回手机装 Tailscale 直连（P2P 打洞）或改用推送式方案。
  **Speed**: Funnel always relays through Tailscale's cloud edge; measured ~2–3.5s per request from CN networks (round trip to an overseas edge). Use Tailscale direct (P2P) on the phone or a push-based design if latency matters.
- **安全**：Funnel 把服务**暴露到公网**，任何知道 URL 的人都能发起请求——务必保留 6 位 token，并考虑失败限速。
  **Security**: Funnel **exposes the service to the public internet**; anyone with the URL can hit it. Keep the 6-digit token and consider rate-limiting.
- 关闭 Funnel：`tailscale funnel --https=443 off`。app 从菜单正常退出（Quit）时会自动执行此命令；`start.sh`/kill 不会触发（新实例启动时会自动重新接管）。
  To disable: `tailscale funnel --https=443 off`. The app runs this automatically when you quit it from the menu (Quit); `start.sh`/kill does not trigger it (the next instance re-configures on start).

---

## 重要：必须用 start.sh 启动，不要从 /Applications 启动

> Important: launch via `./start.sh`, **not** from `/Applications`

**中文**：Debug 构建是 **ad-hoc 签名**。macOS 的辅助功能（TCC）权限同时绑定「签名哈希」和「app 路径」。从不同路径启动同一个二进制（例如复制到 `/Applications` 后启动）会**静默丢失权限**，键盘注入失效——但其他一切看起来都正常（页面能开、状态正常、显示已批准）。`start.sh` 总是从授权时的原路径启动。

**English**: Debug builds are **ad-hoc signed**. macOS's Accessibility (TCC) permission is bound to *both* the signature hash and the app's path. Launching the same binary from a different path (e.g. after copying it to `/Applications`) silently loses the permission, so keystroke injection stops working even though everything else looks fine (page loads, status works, shows "approved"). `start.sh` always launches from the path the permission was granted on.

**中文**：另外，**重新构建会改变签名哈希**，可能再次使辅助功能权限失效。如果解锁突然失效，去 系统设置 → 隐私与安全性 → 辅助功能，把 BLEUnlock 取消勾选再勾选（必要时重启 app）。

**English**: Also, **rebuilding changes the signature hash**, which may invalidate the Accessibility permission again. If unlock silently stops working, re-grant it in *System Preferences* → *Privacy & Security* → *Accessibility* (turn BLEUnlock off and on again, restart the app if needed).

---

## 已知限制 / Known limitations

- 仅在用户会话存活时工作（**锁屏场景**）；重启/注销后的登录窗口、FileVault 预启动界面**不工作**。重启后仍需手动输一次密码。
  Works only while your user session is alive (**lock screen**); the login window after reboot/logout and the FileVault preboot screen are **not** supported. After a reboot you still need to type your password once.
- macOS Sonoma (14) 起，锁屏运行在独立的 `loginwindow` 上下文，键盘注入在不同 macOS 版本上行为可能不同。这同样影响原版 BLE 接近解锁。
  Since macOS Sonoma (14), the lock screen runs in a separate `loginwindow` context; keystroke injection may behave differently on some macOS versions. This affects the original BLE proximity unlock too.
- 批准动作是模拟键盘输入密码（等价于你自己输密码），**不是 Touch ID**。
  The approve action types the password via simulated keystrokes — functionally equivalent to typing it yourself, **not** Touch ID.

---

## 故障排查 / Troubleshooting

### 「已批准」但 Mac 无反应 / Says "approved" but nothing happens on the Mac

**中文**：说明批准请求已到达 Mac、密码已读取，但最后的**键盘注入被拦截**——几乎总是辅助功能权限问题：
- 确认 app 是用 `./start.sh` 启动的（不是从 `/Applications`）。
- 重新授权：系统设置 → 隐私与安全性 → 辅助功能 → 关闭再打开 BLEUnlock。
- 如果重新构建过 app，ad-hoc 签名变了，权限可能已失效。

**English**: The approve request reached the Mac and the password was read, but the final **keystroke injection was blocked** — almost always an Accessibility permission problem:
- Make sure the app was launched via `./start.sh` (not from `/Applications`).
- Re-grant the Accessibility permission: *System Preferences* → *Privacy & Security* → *Accessibility* → turn BLEUnlock off and on again.
- If you rebuilt the app, the ad-hoc signature changed and the permission may have been invalidated.

### 手机打不开解锁页面 / Can't reach the unlock page from the phone

- 确认手机已连接 Tailscale（Mac 上 `tailscale status` 能看到手机的地址）。
  Confirm your phone is connected to Tailscale (`tailscale status` on the Mac should show the phone's address).
- 确认服务在监听：`lsof -nP -iTCP:8123 -sTCP:LISTEN`。
  Check the server is listening: `lsof -nP -iTCP:8123 -sTCP:LISTEN`.
- 检查 Mac 防火墙没有拦截 8123 端口。
  Check the Mac's firewall is not blocking port `8123`.
- 页面显示 `403` = 请求来源不在 `100.64.0.0/10` 或 `localhost`。
  The page shows `403` if the request does not come from `100.64.0.0/10` or `localhost`.

### 页面提示 invalid token (401) / Page shows "invalid token" (401)

**中文**：token 必须与菜单（菜单栏 → Remote Unlock）里显示的一致。如果用 *Set Access Token…* 改过，需要在手机上重新输入（页面会在 `localStorage` 记住旧 token）。

**English**: The token must match the one shown in the menu (menu bar → Remote Unlock). If you changed it with *Set Access Token…*, re-enter it on the phone (the page remembers the old one in `localStorage`).

---

## Debug 指南 / Debugging

- 日志文件：`~/Library/Logs/BLEUnlock/bleunlock.log`（复现问题时 `tail -f`）。
  Log file: `~/Library/Logs/BLEUnlock/bleunlock.log` (`tail -f` while reproducing the issue).
- 日志记录锁定状态转换和远程解锁路径（`Remote: unlock approved, entering password`、`Remote: sending password keystrokes` …）。
  The log records lock-state transitions and the remote unlock path (`Remote: unlock approved, entering password`, `Remote: sending password keystrokes`, ...).
- 注意：`print` 输出重定向到文件时是**缓冲**的（进程退出才 flush）；实时查看用 `log stream --process BLEUnlock`。
  Note: `print` output is **buffered** when redirected to a file (flushed on exit); use `log stream --process BLEUnlock` for real-time unified logging.

---

相关 / Related: [README.md](README.md)
