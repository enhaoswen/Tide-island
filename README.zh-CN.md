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
  <a href="#重要说明">重要说明</a>
</p>

---

## 关于 Tide Island

Tide Island 是一个给 Hyprland 用的小桌面组件，做成了类似灵动岛的样式。

平时没什么事的时候，它就待在角落里，不碍眼；需要看信息的时候，再展开成一个面板，可以看歌词、切换工作区、调系统设置、看通知，或者放几个自定义内容。

这是用 Quickshell、QML 和 C++/Qt 6 写的，主要的功夫都花在让动画尽量顺滑、操作跟手、资源占用也尽量克制上。不敢说有多好，但希望能用得舒服。

---

## 预览

<!--
如果你有 GIF，这一部分会更有吸引力。
<p align="center">
  <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/demo.gif" width="760" alt="Tide Island 演示">
</p>
-->

<table>
  <tr>
    <td width="50%">
      <h3 align="center">时钟模式</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_1.png" width="100%" alt="时钟模式预览">
    </td>
    <td width="50%">
      <h3 align="center">系统通知</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_2.png" width="100%" alt="系统通知预览">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">控制中心</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_3.png" width="100%" alt="控制中心预览">
    </td>
    <td width="50%">
      <h3 align="center">音乐播放器</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_4.png" width="100%" alt="音乐播放器预览">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">工作区指示器</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_5.png" width="100%" alt="工作区指示器预览">
    </td>
    <td width="50%">
      <h3 align="center">歌词</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_6.png" width="100%" alt="歌词预览">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">工作区概览</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_7.png" width="100%" alt="工作区概览预览">
    </td>
    <td width="50%">
      <h3 align="center">自定义页面</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_9.png" width="100%" alt="自定义页面预览">
    </td>
  </tr>
</table>

---

## 功能

### 手势导航

| 输入            | 行为               |
| ------------- | ---------------- |
| 左键点击          | 打开音乐播放器          |
| 右键点击          | 打开控制中心           |
| 向左滑动          | 显示歌词             |
| 向右滑动          | 显示自定义页面          |
| 双指横向 / 纵向滑动   | 在时间、歌词和自定义视图之间切换 |
| `Super + Tab` | 打开工作区概览          |

### 系统反馈

Tide Island 可以显示以下临时反馈：

- 音量变化
- 亮度变化
- 电池充电 / 放电状态
- Caps Lock 状态
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

---

## 性能

当前目标资源占用：

| 指标   | 目标             |
| ---- | -------------- |
| 内存   | `< 200 MB PSS` |
| CPU  | 普通使用时 `< 2%`   |
| 渲染   | 尽可能事件驱动        |
| 桌面环境 | Hyprland       |

实际性能可能会受到启用模块、歌词源、动画和系统配置的影响。

---

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

---

## 启动 Tide Island

Tide Island 提供 systemd 用户服务。

启用并立即启动：

```bash
systemctl --user enable --now tide-island
```

常用命令：

```bash
# 修改配置后重启
systemctl --user restart tide-island

# 停止 Tide Island
systemctl --user stop tide-island

# 查看日志
journalctl --user -u tide-island -f
```

也可以手动启动：

```bash
tide-island
```

如果你更想直接用 Hyprland 管理启动项，可以在 `hyprland.conf` 里加入：

```conf
exec-once = tide-island
```

或者在 `hyprland.lua` 里加入：

```lua
hl.exec_once("tide-island")
```

如果已经启用了 systemd 服务，就不需要再添加 `exec-once`。

---

## 配置

默认用户配置文件位于：

```text
~/.config/tide-island/userconfig.json
```

修改配置后，重启服务：

```bash
systemctl --user restart tide-island
```

---

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

---

## 重要说明

在提交 issue 前，请先阅读这一部分。

### Caps Lock 检测

Caps Lock 状态目前通过 `hyprctl devices` 检测。

请确保 `hyprctl` 已安装，并且可以从 `$PATH` 中访问。

---

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

---

## 贡献

欢迎提交 issue、bug 反馈、设计建议和 pull request。

---

## 致谢

感谢：

- [@end-4](https://github.com/end-4) 提供工作区概览设计灵感
- [@BEST8OY](https://github.com/BEST8OY) 提供歌词支持
- [@gozhuimeng](https://github.com/gozhuimeng) 改进歌词后端

---

## 社区

- Discord: https://discord.gg/gEmqgz76
- Email: enhaoswen@gmail.com

---

<p align="center">
  <sub>
    为喜欢安静、实用、又稍微有点生命感桌面的 Hyprland 用户而做。
  </sub>
</p>
