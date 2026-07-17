<h1 align="center">Tide Island</h1>

<p align="center">
  <b>一个为 Hyprland 和 niri 打造的流畅、轻量、灵活的交互式 Dynamic Island。</b>
</p>

<p align="center">
  <sub>
    <a href="./README.md">English</a>
     · 
    <a href="./README.zh-CN.md">简体中文</a>
  </sub>
</p>

<p align="center">
  <a href="https://github.com/enhaoswen/Tide-island/stargazers">
    <img alt="GitHub stars" src="https://img.shields.io/github/stars/enhaoswen/Tide-island?style=flat-square&color=8aadf4">
  </a>
  <a href="https://github.com/enhaoswen/Tide-island/issues">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues/enhaoswen/Tide-island?style=flat-square&color=8aadf4">
  </a>
  <a href="https://aur.archlinux.org/packages/tide-island">
    <img alt="AUR package" src="https://img.shields.io/aur/version/tide-island?style=flat-square&label=AUR&color=8aadf4">
  </a>
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-111111?style=flat-square&color=8aadf4">
  <img alt="niri" src="https://img.shields.io/badge/niri-111111?style=flat-square&color=8aadf4">
  <img alt="C++ + Qt" src="https://img.shields.io/badge/C%2B%2B%20%2B%20Qt-111111?style=flat-square&color=8aadf4">
</p>

<p align="center">
  <a href="#预览">预览</a>
  ·
  <a href="#功能">功能</a>
  ·
  <a href="#安装">安装</a>
  ·
  <a href="#配置">配置</a>
  ·
  <a href="#常用命令">常用命令</a>
</p>

---

## 关于 Tide Island

Tide Island 是一个给 Hyprland 和 niri 用的小桌面组件，做成了类似灵动岛的样式。

平时没什么事的时候，它就待在角落里，不碍眼；需要看信息的时候，再展开成一个面板，可以看歌词、切换工作区、调系统设置、看通知，或者放几个自定义内容。

这是用 Quickshell、QML 和 C++/Qt 6 写的，主要的功夫都花在让动画尽量顺滑、操作跟手、资源占用也尽量克制上。不敢说有多好，但希望能用得舒服。

<br>

## 预览

### Tide Island

<table>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/mp.png" width="100%" alt="Music player" />
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/msg.png" width="100%" alt="Message preview" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/timer.png" width="100%" alt="Timer" />
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/wallpaper%20switcher.png" width="100%" alt="Wallpaper switcher" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/cc_2.png" width="100%" alt="Control center" />
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Workspace overview_2.png" width="100%" alt="Workspace overview" />
    </td>
  </tr>
</table>

### 配置软件

<img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/config_app.png" width = "90%">
<br>

## 功能

- 时钟
- 音乐播放器
- 计时器
- 控制中心
- 歌词展示页面
- 自定义页面
- 壁纸切换器
- 工作区总览

### 系统反馈

Tide Island 可以显示以下临时反馈：

- 音量变化
- 亮度变化
- 电池充电 / 放电状态
- 工作区切换
- 媒体播放
- 系统通知

### 自定义页面项目

自定义页面可以显示：

- 时间
- 日期
- 电池
- 音量
- 亮度
- 工作区
- CPU
- RAM
- CAVA 音频可视化

### Compositor 支持范围

- Hyprland: 保留完整体验，包括 Tide 自己的工作区总览、工作区动画、快捷键和基于 `hyprsunset` 的 Night Light。
- niri: 支持 island 页面、发往聚焦输出的 IPC 命令、工作区切换提示、niri 原生 overview、通过 `~/.config/tide-island/niri-shortcuts.kdl` 管理快捷键，以及基于 `gammastep` 的 Night Light。
- Tide 会优先读取 `TIDE_ISLAND_COMPOSITOR`，然后识别 `$XDG_CURRENT_DESKTOP`；只有桌面环境未明确给出时才使用 `$NIRI_SOCKET`，最后回退到 Hyprland。这可避免嵌套启动或切换 compositor 后继承的旧 socket 导致误判。

<br>

## 安装

### Arch Linux

从 AUR 安装：

```bash
yay -S tide-island
```

### 其他 Linux 发行版

从[最新 GitHub Release](https://github.com/enhaoswen/Tide-island/releases/latest)
下载源码包和校验文件：

```bash
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/tide-island-source.tar.xz
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xf tide-island-source.tar.xz
cd Tide-island-*
./install.sh
```

安装器会把 Tide Island 固定安装到 `/usr`，仅在安装软件包和文件时请求
`sudo`，并启用 systemd 用户服务。目前可以自动安装以下发行版的依赖：

- Debian、Ubuntu 及其衍生版：`apt`
- Fedora、RHEL 及其衍生版：`dnf`
- openSUSE：`zypper`

Arch 系发行版请使用 AUR。其他 Linux 发行版可以自行安装依赖，然后运行：

```bash
./install.sh --skip-deps
```

如果 `/usr/bin/quickshell` 已存在，安装器会直接使用；否则会构建并校验本版本
固定的 Quickshell 版本。要求 Qt 6.6 或更高版本。

是否支持取决于发行版提供的 Qt 版本，而不只是发行版名称。例如 Ubuntu 24.04
官方仓库提供的是 Qt 6.4，若要使用这个安装器构建固定版本的 Quickshell，需要先
配置较新的 Qt 软件源或源码环境。安装器会明确报错退出，不会混装不兼容的 Qt。

这个源码安装器面向 `/usr` 可写的常规 Linux 系统。NixOS、Fedora Silverblue
等声明式或不可变系统应使用原生软件包，或在可写的开发容器中安装。

常用安装选项：

```bash
./install.sh --no-service
./install.sh --skip-quickshell
./install.sh --force-build-quickshell
./install.sh --uninstall
```

<br>

## 启动 Tide Island

Tide Island 提供 systemd 用户服务。

启用并立即启动：

```bash
systemctl --user enable --now tide-island
```

如果要手动设置自启动，可以在 `hyprland.conf` 里加入:

```conf
exec-once = tide-island
```

或者在 `hyprland.lua` 里加入:

```lua
hl.exec_once("tide-island")
```

如果已经启用了 systemd 服务，就不需要再添加 `exec-once`。

<br>

## 配置

在应用启动器里搜索 `Tide Island Settings`。

快捷键页面可以自动应用绑定。niri 下会生成 `~/.config/tide-island/niri-shortcuts.kdl`，把它 include 到 `~/.config/niri/config.kdl`，先运行 `niri validate`，成功后再用 `niri msg action load-config-file` 重新加载。

<br>

## 常用命令

#### 修改配置后重启:

```bash
systemctl --user restart tide-island
```

#### 停止 Tide Island:

```bash
systemctl --user stop tide-island
```

#### 查看日志:

```bash
journalctl --user -u tide-island -f
```

修改配置后，重启服务：

```bash
systemctl --user restart tide-island
```

<br>

## 贡献

欢迎提交 issue、bug 反馈、设计建议和 pull request。

## 致谢

感谢：

- [@end-4](https://github.com/end-4) 提供工作区概览设计灵感
- [@gozhuimeng](https://github.com/gozhuimeng) 改进歌词后端

## 社区

- Discord: https://discord.gg/gEmqgz76
- Email: enhaoswen@gmail.com

一个卑微的请求: 在发布rice的照片时,能否加上我repo的地址呢? (我的reddit账号被ban了)[哭]

---

<p align="center">
  <sub>
    为喜欢安静,实用桌面的 Hyprland 和 niri 用户而做。
  </sub>
</p>
