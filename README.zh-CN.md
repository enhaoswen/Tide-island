<h1 align="center">🌊 Tide Island</h1>

<p align="center">
  <b>适用于 Hyprland 和 niri 的灵动岛:流畅、轻量、灵活。</b>
</p>

<p align="center">
  <img alt="Stars" src="https://img.shields.io/github/stars/enhaoswen/Tide-island?style=for-the-badge&logo=github">
  <img alt="AUR" src="https://img.shields.io/aur/version/tide-island?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-0.3%2B-5e81ac?style=for-the-badge">
  <img alt="Qt 6" src="https://img.shields.io/badge/Qt-6-41cd52?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-supported-58e1ff?style=for-the-badge">
  <img alt="niri" src="https://img.shields.io/badge/niri-supported-f5c2e7?style=for-the-badge">
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/70948?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-70948" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/70948/daily?language=QML" alt="enhaoswen%2FTide-island | Trendshift" width="250" height="55"/></a>
</p>

<p align="center">
  <sub>
    <a href="./README.md">English</a>
     · 
    <a href="./README.zh-CN.md">简体中文</a>
  </sub>
</p>

<p align="center">
  <a href="#-预览">预览</a>
  ·
  <a href="#-功能">功能</a>
  ·
  <a href="#-安装">安装</a>
  ·
  <a href="#-配置">配置</a>
  ·
  <a href="#-常用命令">常用命令</a>
  ·
  <a href="#-常见问题">常见问题</a>
</p>

---

> [!WARNING]
> **Tide Island 已迁移到新的仓库。**
>
> 当前版本依然可以正常使用,也会继续保留在这里,但**不再积极维护**。
> 新版本正在开发中,但**还没有完成**。
>
> 最新进展请前往 **[Tide Island — 新仓库](https://github.com/enhaoswen/Tide-Island-New)**。

## ✨ 简介

Tide Island 是一个给 Hyprland 和 niri 用的桌面小组件,外观类似 iPhone 的灵动岛。

平时它安静地待在屏幕角落,不打扰你。需要的时候,它会展开成一个面板:你可以看歌词、切换工作区、调整系统设置、查看通知,也可以放上自己的自定义内容。

它使用 Quickshell、QML 和 C++/Qt 6 开发。我花了最多时间在三件事上:动画要流畅、响应要快、资源占用要低。它不算完美,但希望用起来舒服。

<br>

## 🎬 预览

https://github.com/user-attachments/assets/bb3defb8-8af0-4a13-acde-3ed8ee8feef9

<br>

## 🧩 功能

| | 功能 | | 功能 |
| --- | --- | --- | --- |
| 🕒 | 时钟 | 🎵 | 音乐播放器 |
| 🎛️ | 控制中心 | ⏱️ | 计时器 |
| 🎤 | 歌词显示 | 🚀 | 应用启动器 |
| 🗂️ | 文件暂存架 | 📋 | 剪贴板历史 |
| 🌤️ | 天气与预报 | 📅 | 日历(支持备注) |
| 🖼️ | 壁纸切换 | 🪟 | 工作区总览 |
| 🎨 | 自定义页面 | 🔔 | 通知中心 |
| ⏻ | 电源菜单 | 🔒 | 锁屏 |

**几点小说明:**

- **剪贴板历史**需要安装 `cliphist` 和 `wl-clipboard`。Tide Island 运行时会自动启动剪贴板监听。
- **日历:** 点击某个日期就可以写备注。备注会自动保存,有备注的日期下方会显示一个小圆点。

### 📡 系统反馈

发生下面这些事情时,灵动岛会短暂显示提示:

- 音量变化
- 亮度变化
- 电池充电 / 放电
- 工作区切换
- 媒体播放(可选)
- 系统通知

### 🎨 自定义页面

自定义页面可以放这些项目:

| | | | |
| --- | --- | --- | --- |
| 时间 | 日期 | 电池 | 音量 |
| CPU 占用 | 内存占用 | 存储占用 | 亮度 |
| 当前工作区 | 天气 | Cava | |

### 🖥️ 合成器支持

| 合成器 | 支持内容 |
| --- | --- |
| **Hyprland** | 完整体验:Tide 自带的工作区总览、工作区动画、快捷键,以及通过 `hyprsunset` 实现的夜间模式。 |
| **niri** | 灵动岛各视图、针对当前聚焦显示器的 IPC 命令、工作区切换提示、niri 原生总览、通过 `~/.config/tide-island/niri-shortcuts.kdl` 配置的快捷键,以及通过 `gammastep` 实现的夜间模式。 |

<br>

## 📦 安装

### Arch Linux

从 AUR 安装:

```bash
yay -S tide-island
```

### 其他 Linux 发行版

从 [最新的 GitHub Release](https://github.com/enhaoswen/Tide-island/releases/latest) 下载源码包和校验文件,然后安装:

```bash
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/tide-island-source.tar.xz
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xf tide-island-source.tar.xz
cd Tide-island-*
./install.sh
```

安装脚本会把 Tide Island 安装到 `/usr`,并且可以在下面这些系统上自动安装依赖:

- Debian、Ubuntu 及其衍生版(`apt`)
- Fedora、RHEL 及其衍生版(`dnf`)
- openSUSE(`zypper`)

在其他发行版上,请先手动安装依赖,然后运行:

```bash
./install.sh --skip-deps
```

> [!NOTE]
> 这个安装脚本面向 `/usr` 可写的常规 Linux 系统。
> 在声明式或不可变系统上(例如 NixOS、Fedora Silverblue),请使用对应的原生软件包,或者使用可写的开发容器。

<details>
<summary><b>安装脚本选项</b></summary>

<br>

| 选项 | 作用 |
| --- | --- |
| `./install.sh --no-service` | 安装 Tide Island,但不启用也不启动 systemd 用户服务。 |
| `./install.sh --skip-quickshell` | 不从源码编译 Quickshell,直接使用现有的 `/usr/bin/quickshell`。如果这个文件不存在,安装会报错并停止。 |
| `./install.sh --force-build-quickshell` | 即使已经安装了 Quickshell,也重新编译并安装本项目固定的 Quickshell 版本。 |
| `./install.sh --uninstall` | 删除源码安装脚本装上的文件。依赖和 Quickshell 会保留。 |

</details>

<br>

## 🚀 启动 Tide Island

Tide Island 自带一个 systemd 用户服务。推荐用这种方式:

```bash
systemctl --user enable --now tide-island.service
```

如果你想自己管理启动,可以在 Hyprland 配置里加一行。

`hyprland.conf`:

```conf
exec-once = tide-island
```

`hyprland.lua`:

```lua
hl.exec_once("tide-island")
```

> [!TIP]
> 如果已经启用了 systemd 服务,就**不需要**再写 `exec-once`。两个同时用会启动两次。

<br>

## ⚙️ 配置

在应用启动器里搜索 `Tide Island Settings`,或者运行:

```bash
tide-island-config-app
```

### 🔒 锁屏

Tide Island 运行时,有两种方式锁屏:

- 打开 **Settings → Lock screen**,点击 **Lock now**。
- 点击控制中心电源菜单里的锁屏按钮。

你也可以使用快捷键:在 **Shortcut** 页面启用 **Lock screen**(默认 `Super + L`)。

**关于背景模糊**

模糊效果使用 Quickshell 0.3+ 的
[BackgroundEffect](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/BackgroundEffect/),
所以你的合成器需要支持 `ext-background-effect-v1`。
圆角的模糊区域会在过渡动画中跟随可见面板,面板关闭时一起消失。
如果合成器不支持这个协议,你仍然可以看到带色调的表面,只是没有模糊。
layer-shell 的 namespace 是 `tide-island`。

模糊区域位于抗锯齿表面的内侧,带有一圈细而浅的描边。

<details>
<summary><b>Hyprland:调整大小时模糊看起来不对?</b></summary>

<br>

Tide 会自己处理面板动画。而 Hyprland 的 layer 动画可能在此之上再缩放整个表面,导致调整大小时文字被拉伸、模糊位置错开。

如果你使用 Lua 配置,可以只对 Tide 关闭这个额外的动画:

```lua
hl.layer_rule({
    name = "tide-island-native-morph",
    match = { namespace = "^tide-island$" },
    no_anim = true,
})
```

</details>

### 💚 Spotify 收藏

在展开的音乐播放器里,你可以把当前 Spotify 歌曲添加到「已点赞的歌曲」(Liked Songs),或者从中移除。你在 Spotify 客户端里做的修改,也会同步显示在播放器中。

工作方式:它通过 [Spicetify](https://spicetify.app/docs/getting-started) 与本地的 Spotify 桌面客户端通信。这意味着:

- 不需要 Spotify 开发者应用、API Key、浏览器自动化或托管服务器。
- 没有开发者应用的用户白名单限制。
- 使用的是你已登录账号的正常资料库权限,这个功能不需要 Premium。

**设置步骤**

1. 安装或更新 Tide Island。
2. 打开 Spotify 并登录。
3. 安装 Spicetify。
4. 以桌面用户身份运行:

```bash
tide-island-spotify-setup
```

这会安装配套扩展,并在需要时自动创建、复用或迁移原版备份。Spotify 可能会重启。你现有的主题和其他扩展都会保留。
如果你是从源码目录运行,请改用 `python3 scripts/spotify-setup.py`。

**使用方法**

打开展开的播放器,点击右侧的爱心。爱心是实心的,说明这首歌已经收藏。

下面这些情况下,爱心按钮不可用:

- Spotify 未连接,
- 歌曲状态未知,或者
- 还有更新在等待处理。

每个请求都绑定了歌曲的 URI,所以延迟返回的回复不会改变下一首歌的爱心状态。

**安全与配置**

- 桥接服务只监听 `127.0.0.1`,默认端口是 `8976`。
- 配置保存在 `$XDG_CONFIG_HOME/tide-island/spotify-bridge.json`(通常是 `~/.config/tide-island/spotify-bridge.json`)。
- 令牌(token)只用来验证本地桥接服务。Spotify 的密码、Cookie 和访问令牌都不会发送给 Tide Island。

```bash
# 默认端口被占用时,换一个端口
tide-island-spotify-setup --port 9898

# 只准备文件,暂时不应用
tide-island-spotify-setup --no-apply

# 移除配套扩展和桥接配置
tide-island-spotify-setup --remove

# 查看连接、歌曲和收藏状态(不需要账号凭据)
quickshell ipc call tide spotifyFavoritesStatus
```

**限制**

- 目前只支持 Spotify 曲库里的歌曲。本地文件、播客和其他 MPRIS 播放器不会显示爱心。
- 如果 Spotify 更新后收藏功能失效,请更新 Spicetify 并重新运行 setup。需要兼容的 Spotify 桌面客户端和 Spicetify。
- Qt WebSockets 是新增的构建/运行时依赖。Arch 软件包和源码安装脚本的依赖列表里已经包含它。

<br>

## 🛠️ 常用命令

**修改配置后重启**

```bash
systemctl --user restart tide-island
```

**停止 Tide Island**

```bash
systemctl --user stop tide-island
```

**查看日志**

```bash
journalctl --user -u tide-island -f
```

### 📡 IPC 命令

你可以通过 `quickshell ipc call` 在终端、快捷键或脚本里控制 Tide Island。

| 视图 | 切换 | 打开 | 关闭 |
| --- | --- | --- | --- |
| 日历 | `quickshell ipc call tide toggleCalendar` | `quickshell ipc call tide openCalendar` | `quickshell ipc call tide closeCalendar` |
| 天气 | `quickshell ipc call tide toggleWeather` | `quickshell ipc call tide openWeather` | `quickshell ipc call tide closeWeather` |
| 剪贴板历史 | `quickshell ipc call tide toggleClipboard` | `quickshell ipc call tide openClipboard` | `quickshell ipc call tide closeClipboard` |
| 通知中心 | `quickshell ipc call tide toggleNotificationCenter` | `quickshell ipc call tide openNotificationCenter` | `quickshell ipc call tide closeNotificationCenter` |
| 应用启动器 | `quickshell ipc call tide toggleApplicationLauncher` | — | — |

其他命令:

| 命令 | 作用 |
| --- | --- |
| `quickshell ipc call weather refresh` | 立即刷新天气数据 |
| `quickshell ipc call tide spotifyFavoritesStatus` | 显示 Spotify 收藏状态 |

<details>
<summary><b>快捷键示例(Hyprland)</b></summary>

<br>

```conf
bind = SUPER, C, exec, quickshell ipc call tide toggleCalendar
bind = SUPER, V, exec, quickshell ipc call tide toggleClipboard
bind = SUPER, N, exec, quickshell ipc call tide toggleNotificationCenter
bind = SUPER, SPACE, exec, quickshell ipc call tide toggleApplicationLauncher
```

按键可以改成任何你喜欢的组合。

</details>

<br>

## ❓ 常见问题

<details>
<summary><b>灵动岛没有显示出来。</b></summary>

<br>

先检查服务是否在运行,然后查看日志:

```bash
systemctl --user status tide-island
journalctl --user -u tide-island -f
```

同时确认你没有重复启动(systemd 服务**和** `exec-once` 同时使用)。

</details>

<details>
<summary><b>剪贴板历史是空的。</b></summary>

<br>

请检查是否已经安装 `cliphist` 和 `wl-clipboard`。

</details>

<details>
<summary><b>没有模糊效果。</b></summary>

<br>

你的合成器可能不支持 `ext-background-effect-v1`。这时 Tide Island 会显示带色调但没有模糊的表面,属于正常现象。

</details>

<details>
<summary><b>夜间模式不工作。</b></summary>

<br>

在 Hyprland 上需要 `hyprsunset`,在 niri 上需要 `gammastep`。

</details>

<br>

## 🤝 参与贡献

欢迎提交 Issue、Bug 报告、设计建议和 Pull Request。

- 请**一个 Issue 只讨论一个主题**。
- 提交 PR 之前,请**先说一下你的想法**。

## 💐 致谢

感谢:

- [@end-4](https://github.com/end-4):工作区总览设计的灵感来源
- [@gozhuimeng](https://github.com/gozhuimeng):改进了歌词后端
- [@LatifKovani](https://github.com/LatifKovani):带来了重大改进

## 💬 社区

- Discord: <https://discord.gg/Rcj3uPtKwD>
- 邮箱: <enhaoswen@gmail.com>

## ⭐ Star 历史

<a href="https://star-history.com/#enhaoswen/Tide-island&Date">
  <picture>
    <source
      media="(prefers-color-scheme: dark)"
      srcset="https://api.star-history.com/svg?repos=enhaoswen/Tide-island&type=Date&theme=dark"
    />
    <source
      media="(prefers-color-scheme: light)"
      srcset="https://api.star-history.com/svg?repos=enhaoswen/Tide-island&type=Date"
    />
    <img
      alt="Star History Chart"
      src="https://api.star-history.com/svg?repos=enhaoswen/Tide-island&type=Date"
    />
  </picture>
</a>

---

<p align="center">
  <sub>
    献给喜欢安静、实用桌面的 Wayland 用户。🌊
  </sub>
</p>
