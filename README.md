<h1 align="center">Tide Island</h1>

<p align="center">
  <b>A smooth, lightweight, and flexible interactive Dynamic Island for Hyprland and niri.</b>
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
  <a href="#preview">Preview</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#installation">Installation</a>
  ·
  <a href="#configuration">Configuration</a>
  ·
  <a href="#common-commands">Common Commands</a>
  ·
  <a href="#notification-centre">Notification Centre</a>
</p>

---

## About Tide Island

Tide Island is a small desktop widget for Hyprland and niri, styled like the Dynamic Island.

When nothing much is going on, it just sits in the corner, staying out of the way. When you need to check some information, it expands into a panel where you can view lyrics, switch workspaces, adjust system settings, check notifications, or put in some custom content.

It's built with Quickshell, QML, and C++/Qt 6. Most of the effort went into making the animations as smooth as possible, interactions responsive, and resource usage kept in check. I can't claim it's anything special, but I hope it's comfortable to use.

<br>

## Preview

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

### Config App

<img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/config_app.png" width = "90%">
<br>

## Features

- Clock
- Music player
- Control Center
- Timer
- Lyrics displayer
- Application launcher (`Super + /` by default)
- Wallpaper switcher
- Workspace overview
- Custom page
- Notification Centre



### System Feedback

- Volume changes
- Brightness changes
- Battery charging / discharging
- Workspace changes
- Media playback (optional)
- System notifications



### Custom Page

- Time
- Date
- Battery
- Volume
- CPU usage
- Current workspace
- Memory usage
- Brightness
- Cava
- Storage usage

### Compositor support

- Hyprland: full current experience, including Tide's workspace overview, workspace animations, shortcuts, and Night Light through `hyprsunset`.
- niri: island views, focused-output IPC commands, workspace change hints, native niri overview, shortcuts through `~/.config/tide-island/niri-shortcuts.kdl`, and Night Light through `gammastep`.
- Tide checks `TIDE_ISLAND_COMPOSITOR` first, then `$XDG_CURRENT_DESKTOP`. It uses `$NIRI_SOCKET` only when the desktop environment is inconclusive, then falls back to Hyprland. This prevents inherited compositor sockets from causing a false detection.

<br>

## Installation

### Arch Linux

Install from the AUR:

```bash
yay -S tide-island
```

### Other Linux distributions

Download the source package and checksum from the
[latest GitHub Release](https://github.com/enhaoswen/Tide-island/releases/latest):

```bash
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/tide-island-source.tar.xz
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xf tide-island-source.tar.xz
cd Tide-island-*
./install.sh
```

The installer writes Tide Island to `/usr` and can automatically install
dependencies on:

- Debian, Ubuntu, and derivatives using `apt`
- Fedora, RHEL, and derivatives using `dnf`
- openSUSE using `zypper`

For other distributions, install the dependencies manually and run:

```bash
./install.sh --skip-deps
```

Quickshell is used from `/usr/bin/quickshell` when available. Otherwise the
installer builds the pinned, verified Quickshell version compatible with this
release. Qt 6.6 or newer is required.

Support is determined by the Qt version shipped by the distribution, not only
its name. For example, Ubuntu 24.04 ships Qt 6.4 in its official repositories,
so it needs a newer Qt source/repository before this installer can build the
pinned Quickshell. The installer stops with a clear error instead of mixing
incompatible Qt versions.

This source installer targets conventional Linux systems with a writable
`/usr`. Declarative or immutable systems such as NixOS and Fedora Silverblue
should use a native package or a mutable development container instead.

Useful installer options:

| Option | Description |
| --- | --- |
| `./install.sh --no-service` | Install Tide Island without enabling or starting the systemd user service. |
| `./install.sh --skip-quickshell` | Skip building Quickshell from source and use the existing `/usr/bin/quickshell`; installation stops with an error if that file does not exist. |
| `./install.sh --force-build-quickshell` | Rebuild and install the project's pinned Quickshell version even when Quickshell is already installed. |
| `./install.sh --uninstall` | Remove the Tide Island files installed by the source installer; installed dependencies and Quickshell are kept. |

<br>

## Starting Tide Island

Tide Island provides a systemd user service.

Enable and start it immediately (Recommended):

```bash
systemctl --user enable --now tide-island
```

If you want to manage startup manually, add this to your `hyprland.conf`:

```conf
exec-once = tide-island
```

Or add this to `hyprland.lua`:

```lua
hl.exec_once("tide-island")
```

If the systemd service is already enabled, you do not need to add `exec-once`.

<br>

## Configuration

Search `Tide Island Settings` in any application launcher

The Shortcut page can apply bindings automatically. On niri it writes `~/.config/tide-island/niri-shortcuts.kdl`, includes it from `~/.config/niri/config.kdl`, validates with `niri validate`, then reloads niri with `niri msg action load-config-file`.



## Common Commands

#### Restart after editing the configuration:

```bash
systemctl --user restart tide-island
```

#### Stop Tide Island:

```bash
systemctl --user stop tide-island
```

#### View logs:

```bash
journalctl --user -u tide-island -f
```

#### IPC Commands

Tide Island can be controlled remotely via `quickshell ipc call`:

| Command | Action |
| --- | --- |
| `quickshell ipc call tide toggleNotificationCenter` | Open or close the Notification Centre |
| `quickshell ipc call tide openNotificationCenter` | Open the Notification Centre |
| `quickshell ipc call tide closeNotificationCenter` | Close the Notification Centre |
| `quickshell ipc call tide toggleApplicationLauncher` | Open or close the application launcher |

<br>

## Notification Centre

The Notification Centre is a scrollable history panel that collects all incoming system notifications. It opens as a centred overlay above the island capsule, displaying each notification as a card with the app icon, summary, body, and timestamp.

### Opening the Notification Centre

- **IPC commands** — see [IPC Commands](#common-commands) above
- **Keybind** — bind a key to call `quickshell ipc call tide toggleNotificationCenter` in your Hyprland config:
  ```conf
  bind = $mainMod, N, exec, quickshell ipc call tide toggleNotificationCenter
  ```
  Or in Lua:
  ```lua
  hl.keybind("$mainMod", "N", "quickshell ipc call tide toggleNotificationCenter")
  ```

### Behaviour

- Notifications are automatically stored in the history when they arrive via the system notification daemon
- The list is capped at 50 notifications — oldest entries are removed first
- Each card shows the app name, summary text, body (if present), and relative timestamp
- Use **Clear all** in the header to dismiss every notification at once
- Tap the **✕** button or dismiss to close the panel
- The panel height adjusts dynamically based on the notification list content

### Dismissing notifications

Individual notifications can be dismissed by tapping the × button on the card. Use **Clear all** to remove all notifications at once.

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

## Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the workspace overview design inspiration
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend
- [@LatifKovani](https://github.com/LatifKovani) for a significant improvement

## Community

- Discord: https://discord.gg/gEmqgz76
- Email: enhaoswen@gmail.com

---

<p align="center">
  <sub>
    Made for Wayland users who like quiet and practical desktops.
  </sub>
</p>
