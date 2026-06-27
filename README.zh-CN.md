<h1 align="center">Tide Island</h1>

<p align="center">
  <b>一个为 Hyprland 打造的流畅、轻量、灵活的交互式 Dynamic Island。</b>
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
  </a>
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

Tide Island 是一个给 Hyprland 用的小桌面组件，做成了类似灵动岛的样式。

平时没什么事的时候，它就待在角落里，不碍眼；需要看信息的时候，再展开成一个面板，可以看歌词、切换工作区、调系统设置、看通知，或者放几个自定义内容。

这是用 Quickshell、QML 和 C++/Qt 6 写的，主要的功夫都花在让动画尽量顺滑、操作跟手、资源占用也尽量克制上。不敢说有多好，但希望能用得舒服。

<br>

## 预览

<table>
  <tr>
    <td width="50%">
      <h3 align="center">时钟</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/clock.png" width="100%" alt="Clock mode preview">
    </td>
    <td width="50%">
      <h3 align="center">系统通知</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/msg.png" width="100%" alt="System notification preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">控制中心</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/cc_1.png" width="100%" alt="Control center preview">
    </td>
    <td width="50%">
      <h3 align="center">音乐播放器</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/player.png" width="100%" alt="Music player preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">蓝牙连接状态</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/onBTConnected.png" width="100%" alt="Workspace indicator preview">
    </td>
    <td width="50%">
      <h3 align="center">工作区总览</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/overview.png" width="100%" alt="Workspace overview preview">
    </td>
    
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">歌词</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/lyrics.png" width="100%" alt="Lyrics preview">
    </td>
    <td width="50%">
      <h3 align="center">自定义</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/custom.png" width="100%" alt="Custom page preview">
    </td>
  </tr>
</table>

<br>

## 功能

### 手势导航

| 输入            | 行为               |
| ------------- | ---------------- |
| 左键点击          | 打开音乐播放器          |
| 右键点击          | 打开控制中心           |
| 向左滑动          | 显示自定义页面          |
| 向右滑动          | 显示歌词             |
| 双指横向 / 纵向滑动   | 在时间、歌词和自定义视图之间切换 |
| `Super + Tab` | 打开工作区概览          |

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



## 性能

**内存**: < 200 Mb

**CPU**  正常情况下<1%

> 实际性能可能会受到启用模块、歌词源、动画和系统配置的影响。

<br>

## 安装

### Arch Linux

从 AUR 安装：

```bash
yay -S tide-island
```

或者手动构建：

```bash
git clone https://github.com/enhaoswen/Tide-island.git
cd Tide-island
makepkg -si
```

### Ubuntu / Debian

克隆仓库后运行安装脚本：

```bash
git clone https://github.com/enhaoswen/Tide-island.git
cd Tide-island
./scripts/install-debian-ubuntu.sh
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

#### 检查配置是否缺失:
```bash
tide-island-setup --check
```

这会列出所有缺失的配置项，并为无需交互的配置项写入默认值。

#### 如果配置缺失则设置:
```bash
tide-island-setup --launch
```

#### 启动引导:
```bash
tide-island-setup --wizard
```

## 配置

可以根据自己的喜好在 `~/.config/tide-island/userconfig.json`配置tide island.

| 选项 | 含义 | 类型 | 默认值 |
|---|---|---|---|
| `wallpaperPath` | 当前壁纸文件路径，供 awww 和工作区概览使用 | string | `""` |
| `wallpaperLibraryPath` | 壁纸选择器扫描的图库目录 | string | `""` |
| `iconFontFamily` | 灵动岛图标字体 | string | `"JetBrainsMono Nerd Font"` |
| `textFontFamily` | 通用正文字体 | string | `"Inter Display"` |
| `heroFontFamily` | 大标题字体（歌曲名、控制中心标题等） | string | `"Inter Display"` |
| `timeFontFamily` | 时间显示字体 | string | `"Inter Display"` |
| `tlpPermissionMode` | TLP 省电模式切换的提权方式 | string | `"ask"` |
| `tlpSudoPassword` | `tlpPermissionMode` 为 `"password"` 时使用的 sudo 密码 | string | `""` |
| `overviewGlobalShortcutAppid` | 工作区概览全局快捷键的 App ID | string | `"quickshell"` |
| `overviewGlobalShortcutName` | 工作区概览全局快捷键名称 | string | `"dynamic-island-overview"` |
| `workspaceOverviewWindowDragButton` | 工作区概览中拖拽窗口的鼠标按键 | int | `1`（左键） |
| `dynamicIslandPrimaryButton` | 点击灵动岛胶囊的主鼠标按键 | int | `1`（左键） |
| `dynamicIslandPrimaryAction` | 主按键点击灵动岛触发的操作 | string | `"toggleExpandedPlayer"` |
| `dynamicIslandSecondaryButton` | 点击灵动岛胶囊的副鼠标按键 | int | `3`（右键） |
| `dynamicIslandSecondaryAction` | 副按键点击灵动岛触发的操作 | string | `"toggleControlCenter"` |
| `dynamicIslandLeftSwipeItems` | 左滑灵动岛胶囊时显示的信息卡片 | array | `["cava", "battery"]` |
| `disableAutoExpandOnTrackChange` | 切歌时不自动展开音乐播放器 | bool | `false` |

<br>

也可以修改按键绑定

| 动作 | 行为 |
|---|---|
| `""` / `"none"` | 无操作 |
| `"toggleExpandedPlayer"` | 展开/收起音乐播放器 |
| `"openExpandedPlayer"` | 展开音乐播放器 |
| `"closeExpandedPlayer"` | 收起音乐播放器 |
| `"toggleControlCenter"` | 展开/收起控制中心 |
| `"openControlCenter"` | 展开控制中心 |
| `"closeControlCenter"` | 收起控制中心 |
| `"toggleOverview"` | 展开/收起工作区概览 |
| `"openOverview"` | 展开工作区概览 |
| `"closeOverview"` | 收起工作区概览 |
| `"toggleLyrics"` | 展开/收起歌词胶囊 |
| `"showLyrics"` | 展开歌词胶囊 |
| `"showTime"` | 展开时间胶囊 |
| `"restoreRestingCapsule"` | 恢复灵动岛默认状态 |

例子:
```
"dynamicIslandPrimaryButton": 1,
"dynamicIslandPrimaryAction": "toggleExpandedPlayer",
"dynamicIslandSecondaryButton": 3,
"dynamicIslandSecondaryAction": "toggleControlCenter"
```
1 = 左键, 2 = 中键, 3 = 右键

<br>

## 快携键
非必要,可根据自己的喜好选择或修改

`~/.config/hypr/hyprland.conf` 命令.

```
bind = $mainMod, right, exec, qs ipc -p /usr/share/tide-island call tide showLyrics
bind = $mainMod, left,  exec, qs ipc -p /usr/share/tide-island call tide showCustom
bind = $mainMod, down,  exec, qs ipc -p /usr/share/tide-island call tide showClock
bind = $mainMod, M, exec, qs ipc -p /usr/share/tide-island call tide togglePlayer
bind = $mainMod, C, exec, qs ipc -p /usr/share/tide-island call tide toggleControlCenter
```

`~/.config/hypr/hyprland.lua` 命令.

```
hyprland.bind("SUPER", "right", "exec", "qs ipc -p /usr/share/tide-island call tide showLyrics")
hyprland.bind("SUPER", "left",  "exec", "qs ipc -p /usr/share/tide-island call tide showCustom")
hyprland.bind("SUPER", "down",  "exec", "qs ipc -p /usr/share/tide-island call tide showClock")
hyprland.bind("SUPER", "M", "exec", "qs ipc -p /usr/share/tide-island call tide togglePlayer")
hyprland.bind("SUPER", "C", "exec", "qs ipc -p /usr/share/tide-island call tide toggleControlCenter")
```

<br>

默认用户配置文件位于：

```text
~/.config/tide-island/userconfig.json
```

引导程序会创建完整 JSON。大多数配置项使用默认值；`wallpaperPath`、`wallpaperLibraryPath` 和 `tlpSudoPassword` 依赖本机环境，所以由引导程序交互填写。

修改配置后，重启服务：

```bash
systemctl --user restart tide-island
```

<br>

## 依赖

### 必需依赖

- Hyprland
- Quickshell
- Qt 6
- `hyprctl`
- `wpctl`
- `brightnessctl`
- `pactl`
- `dbus-monitor`
- UPower
- BlueZ
- `libudev`

### 可选 / 功能相关依赖

- NetworkManager 或 iwd，用于 Wi-Fi 集成
- Nerd Font，用于图标显示
- CAVA，用于音频可视化
- 支持 MPRIS 的音乐播放器，用于媒体信息集成

<br>

## 故障排查

### Tide Island 无法启动

查看日志：

```bash
journalctl --user -u tide-island -f
```

确认 Hyprland、Quickshell 和所需命令行工具已经安装。

### 音乐信息不显示

检查播放器是否暴露 MPRIS：

```bash
busctl --user list | grep -i mpris
```

### Wi-Fi 或蓝牙信息不显示

确认相关服务正在运行：

```bash
systemctl status NetworkManager
systemctl status bluetooth
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
    为喜欢安静,实用桌面的 Hyprland 用户而做。
  </sub>
</p>
