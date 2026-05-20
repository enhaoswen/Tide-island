<h1 align="center">Tide Island</h1>

<p align="center">
  <b>A smooth, lightweight, and flexible interactive island for Hyprland.</b>
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
  <a href="#preview">Preview</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#installation">Installation</a>
  ·
  <a href="#configuration">Configuration</a>
  ·
  <a href="#important-notes">Important Notes</a>
</p>

---

## About Tide Island

Tide Island is a small desktop widget for Hyprland, styled like the Dynamic Island.

When nothing much is going on, it just sits in the corner, staying out of the way. When you need to check some information, it expands into a panel where you can view lyrics, switch workspaces, adjust system settings, check notifications, or put in some custom content.

It's built with Quickshell, QML, and C++/Qt 6. Most of the effort went into making the animations as smooth as possible, interactions responsive, and resource usage kept in check. I can't claim it's anything special, but I hope it's comfortable to use.


---

## Performance

Current target usage:

| Metric    | Target                      |
| --------- | --------------------------- |
| Memory    | `< 200 MB PSS`              |
| CPU       | `< 2%` during normal use    |
| Rendering | Event-driven where possible |
| Desktop   | Hyprland                    |

Performance may vary depending on enabled modules, lyrics providers, animations, and system configuration.

---

## Preview

<!--
If you have a GIF, this section becomes much stronger.
<p align="center">
  <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/demo.gif" width="760" alt="Tide Island demo">
</p>
-->

<table>
  <tr>
    <td width="50%">
      <h3 align="center">Clock Mode</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_1.png" width="100%" alt="Clock mode preview">
    </td>
    <td width="50%">
      <h3 align="center">System Notifications</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_2.png" width="100%" alt="System notification preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Control Center</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_3.png" width="100%" alt="Control center preview">
    </td>
    <td width="50%">
      <h3 align="center">Music Player</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_4.png" width="100%" alt="Music player preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Workspace Indicator</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_5.png" width="100%" alt="Workspace indicator preview">
    </td>
    <td width="50%">
      <h3 align="center">Lyrics</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_6.png" width="100%" alt="Lyrics preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Workspace Overview</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_7.png" width="100%" alt="Workspace overview preview">
    </td>
    <td width="50%">
      <h3 align="center">Custom Page</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_9.png" width="100%" alt="Custom page preview">
    </td>
  </tr>
</table>

---

## Features

### Gesture Navigation

| Input                                  | Behavior                                      |
| -------------------------------------- | --------------------------------------------- |
| Left click                             | Open music player                             |
| Right click                            | Open control center                           |
| Swipe left                             | Show lyrics                                   |
| Swipe right                            | Show custom page                              |
| Two-finger horizontal / vertical swipe | Switch between time, lyrics, and custom views |
| `Super + Tab`                          | Open workspace overview                       |

### System Feedback

Tide Island can display temporary feedback for:

- Volume changes
- Brightness changes
- Battery charging / discharging
- Caps Lock state
- Workspace changes
- Media playback
- System notifications

### Custom Page Items

The custom page can display:

- Time
- Date
- Battery
- Volume
- Brightness
- Workspace
- CPU
- RAM
- CAVA audio visualizer

---

## Installation

### Arch Linux

Install from the AUR:

```bash
yay -S tide-island
```

Or build manually:

```bash
git clone https://github.com/enhaoswen/Tide-island.git
cd Tide-island
makepkg -si
```

---

## Starting Tide Island

Tide Island provides a systemd user service.

Enable and start it with:

```bash
systemctl --user enable --now tide-island
```

Useful commands:

```bash
# Restart after config changes
systemctl --user restart tide-island

# Stop Tide Island
systemctl --user stop tide-island

# View logs
journalctl --user -u tide-island -f
```

You can also start it manually:

```bash
tide-island
```

If you prefer managing startup from Hyprland directly, add this to your `hyprland.conf`:

```conf
exec-once = tide-island
```

Or `hyprland.lua`:

```lua
hl.exec_once("tide-island")  
```

If the systemd service is enabled, you do not need the `exec-once` line.

---

## Configuration

The default user configuration is located at:

```text
~/.config/tide-island/userconfig.json
```

After editing the configuration, restart the service:

```bash
systemctl --user restart tide-island
```

---

## Dependencies

### Required

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

### Optional / feature-dependent

- NetworkManager or iwd for Wi-Fi integration
- A Nerd Font for icons
- CAVA for audio visualization
- MPRIS-compatible music player for media integration

---

## Important Notes

Please read this section before opening an issue.

### Caps Lock detection

Caps Lock status is currently checked through `hyprctl devices`.

Make sure `hyprctl` is installed and available in your `$PATH`.

---

## Troubleshooting

### Tide Island does not start

Check logs:

```bash
journalctl --user -u tide-island -f
```

Make sure Hyprland, Quickshell, and required command-line tools are installed.

### Music information does not show

Check whether your player exposes MPRIS:

```bash
busctl --user list | grep -i mpris
```

### Wi-Fi or Bluetooth information does not show

Make sure the relevant services are running:

```bash
systemctl status NetworkManager
systemctl status bluetooth
```

---

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

---

## Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the workspace overview design inspiration
- [@BEST8OY](https://github.com/BEST8OY) for lyrics support
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend

---

## Community

- Discord: https://discord.gg/gEmqgz76
- Email: enhaoswen@gmail.com

---

<p align="center">
  <sub>
    Made for Hyprland users who like their desktop calm, useful, and slightly alive.
  </sub>
</p