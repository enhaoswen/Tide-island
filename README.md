<h1 align="center">Tide Island</h1>

<p align="center">
  <b>A smooth, lightweight, and flexible interactive Dynamic Island for Hyprland.</b>
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
</p>

---

## About Tide Island

Tide Island is a small desktop widget for Hyprland, styled like the Dynamic Island.

When nothing much is going on, it just sits in the corner, staying out of the way. When you need to check some information, it expands into a panel where you can view lyrics, switch workspaces, adjust system settings, check notifications, or put in some custom content.

It's built with Quickshell, QML, and C++/Qt 6. Most of the effort went into making the animations as smooth as possible, interactions responsive, and resource usage kept in check. I can't claim it's anything special, but I hope it's comfortable to use.

<br>

## Preview

<table>
  <tr>
    <td width="50%">
      <h3 align="center">Clock Mode</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/clock.png" width="100%" alt="Clock mode preview">
    </td>
    <td width="50%">
      <h3 align="center">System Notifications</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/msg.png" width="100%" alt="System notification preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Control Center</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/cc_1.png" width="100%" alt="Control center preview">
    </td>
    <td width="50%">
      <h3 align="center">Music Player</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/player.png" width="100%" alt="Music player preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Bluetooth Connection Status</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/onBTConnected.png" width="100%" alt="Bluetooth connection status preview">
    </td>
    <td width="50%">
      <h3 align="center">Workspace Overview</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/overview.png" width="100%" alt="Workspace overview preview">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3 align="center">Lyrics</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/lyrics.png" width="100%" alt="Lyrics preview">
    </td>
    <td width="50%">
      <h3 align="center">Custom Page</h3>
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/custom.png" width="100%" alt="Custom page preview">
    </td>
  </tr>
</table>

<br>

## Features

### Gesture Navigation

| Input                                  | Behavior                                      |
| -------------------------------------- | --------------------------------------------- |
| Left click                             | Open music player                             |
| Right click                            | Open control center                           |
| Swipe left                             | Show custom page                              |
| Swipe right                            | Show lyrics                                   |
| Two-finger horizontal / vertical swipe | Switch between time, lyrics, and custom views |
| `Super + Tab`                          | Open workspace overview                       |

### System Feedback

Tide Island can display temporary feedback for:

- Volume changes
- Brightness changes
- Battery charging / discharging
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

## Performance

**Memory**: <300 Mb

**CPU usage**: < 1 during normal use

> Performance may vary depending on enabled modules, lyrics providers, animations, and system configuration.

<br>

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

### Ubuntu / Debian

Clone the repository and run the installer:

```bash
git clone https://github.com/enhaoswen/Tide-island.git
cd Tide-island
./scripts/install-debian-ubuntu.sh
```

<br>

## Starting Tide Island

Tide Island provides a systemd user service.

Enable and start it immediately:

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

#### Check whether configuration files are missing:

```bash
tide-island-setup --check
```

#### Set up missing configuration files:

```bash
tide-island-setup --launch
```

#### Launch setup wizard:

```bash
tide-island-setup --wizard
```

## Configuration

you can adjust configuration to your liking in `~/.config/tide-island/userconfig.json`.

| Option | Meaning | Type | Default |
|---|---|---|---|
| `wallpaperPath` | Current wallpaper file used by awww and workspace overview | string | `""` |
| `wallpaperLibraryPath` | Directory scanned by the wallpaper picker | string | `""` |
| `iconFontFamily` | Font family for icons/glyphs throughout the island | string | `"JetBrainsMono Nerd Font"` |
| `textFontFamily` | Font family for general body/UI text | string | `"Inter Display"` |
| `heroFontFamily` | Font family for large headings (track title, control center titles) | string | `"Inter Display"` |
| `timeFontFamily` | Font family for clock/time display text | string | `"Inter Display"` |
| `tlpPermissionMode` | How to obtain sudo permissions for TLP battery mode switching | string | `"ask"` |
| `tlpSudoPassword` | Sudo password used when `tlpPermissionMode` is `"password"` | string | `""` |
| `overviewGlobalShortcutAppid` | App ID for registering the overview global shortcut | string | `"quickshell"` |
| `overviewGlobalShortcutName` | Shortcut name for overview toggle | string | `"dynamic-island-overview"` |
| `workspaceOverviewWindowDragButton` | Mouse button used to drag window tiles in workspace overview | int | `1` (Left) |
| `dynamicIslandPrimaryButton` | Primary mouse button for clicking the island capsule | int | `1` (Left) |
| `dynamicIslandPrimaryAction` | Action triggered by primary button click on the island | string | `"toggleExpandedPlayer"` |
| `dynamicIslandSecondaryButton` | Secondary mouse button for clicking the island capsule | int | `3` (Right) |
| `dynamicIslandSecondaryAction` | Action triggered by secondary button click on the island | string | `"toggleControlCenter"` |
| `dynamicIslandLeftSwipeItems` | Cards shown when swiping left on the island pill | array | `["cava", "battery"]` |
| `disableAutoExpandOnTrackChange` | Prevent auto-expanding the player when track changes | bool | `false` |

<br>

You can also change the key binding.

| Action | Behavior |
|---|---|
| `""` / `"none"` | Do nothing |
| `"toggleExpandedPlayer"` | Show/hide the expanded music player |
| `"openExpandedPlayer"` | Open the expanded music player |
| `"closeExpandedPlayer"` | Close the expanded music player |
| `"toggleControlCenter"` | Show/hide the control center panel |
| `"openControlCenter"` | Open the control center panel |
| `"closeControlCenter"` | Close the control center panel |
| `"toggleOverview"` | Show/hide the workspace overview |
| `"openOverview"` | Open the workspace overview |
| `"closeOverview"` | Close the workspace overview |
| `"toggleLyrics"` | Show/hide the lyrics capsule |
| `"showLyrics"` | Show the lyrics capsule |
| `"showTime"` | Show the time capsule |
| `"restoreRestingCapsule"` | Restore default resting capsule state |

Example:

```
"dynamicIslandPrimaryButton": 1,
"dynamicIslandPrimaryAction": "toggleExpandedPlayer",
"dynamicIslandSecondaryButton": 3,
"dynamicIslandSecondaryAction": "toggleControlCenter"
```

1 = Left click, 2 = Middle click, 3 = Right click

<br>

## Shortcuts

Not required, you can adjust based on your preferences.

Shortcuts for `~/.config/hypr/hyprland.conf`. 

```
bind = $mainMod, right, exec, qs ipc -p /usr/share/tide-island call tide showLyrics
bind = $mainMod, left,  exec, qs ipc -p /usr/share/tide-island call tide showCustom
bind = $mainMod, down,  exec, qs ipc -p /usr/share/tide-island call tide showClock
bind = $mainMod, M, exec, qs ipc -p /usr/share/tide-island call tide togglePlayer
bind = $mainMod, C, exec, qs ipc -p /usr/share/tide-island call tide toggleControlCenter
```

Shortcuts for `~/.config/hypr/hyprland.lua`.

```
hyprland.bind("SUPER", "right", "exec", "qs ipc -p /usr/share/tide-island call tide showLyrics")
hyprland.bind("SUPER", "left",  "exec", "qs ipc -p /usr/share/tide-island call tide showCustom")
hyprland.bind("SUPER", "down",  "exec", "qs ipc -p /usr/share/tide-island call tide showClock")
hyprland.bind("SUPER", "M", "exec", "qs ipc -p /usr/share/tide-island call tide togglePlayer")
hyprland.bind("SUPER", "C", "exec", "qs ipc -p /usr/share/tide-island call tide toggleControlCenter")
```

<br>

The default user configuration file is located at:

```text
~/.config/tide-island/userconfig.json
```

After editing the configuration, restart the service:

```bash
systemctl --user restart tide-island
```

<br>

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

<br>

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

<br>

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

## Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the workspace overview design inspiration
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend

## Community

- Discord: https://discord.gg/gEmqgz76
- Email: enhaoswen@gmail.com

---

<p align="center">
  <sub>
    Made for Hyprland users who like quiet and practical desktops.
  </sub>
</p>
