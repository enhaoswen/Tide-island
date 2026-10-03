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
  <a href="https://github.com/enhaoswen/Tide-island/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/enhaoswen/Tide-island?style=flat-square&color=8aadf4"></a>
  <a href="https://github.com/enhaoswen/Tide-island/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/enhaoswen/Tide-island?style=flat-square&color=8aadf4"></a>
  <a href="https://aur.archlinux.org/packages/tide-island"><img alt="AUR package" src="https://img.shields.io/aur/version/tide-island?style=flat-square&label=AUR&color=8aadf4"></a>
  <a href="https://deepwiki.com/enhaoswen/Tide-island"><img alt="Ask DeepWiki" src="https://deepwiki.com/badge.svg"></a>
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

> [!WARNING]
> **Tide Island has moved to a new repository.**
>
> This version is still working well and remains available, but it is no longer actively maintained.
>
> A new version is currently under development, but it is **not finished yet**.
>
> For the latest development, visit **[Tide Island — New Repository](https://github.com/enhaoswen/Tide-Island-New)**.


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
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/weather.png" width="100%" alt="Weather & Forecast" />
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/calendar.png" width="100%" alt="Calendar" />
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/clipboard.png" width="100%" alt="Clipboard history" />
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
- Application launcher
- File shelf
- Clipboard history manager
- Weather & Forecast
- Calendar
- Wallpaper switcher
- Workspace overview
- Custom page
- Notification Centre
- Power menu

Clipboard history requires `cliphist` and `wl-clipboard`. Tide Island starts the clipboard watcher automatically while it is running.
Click a date in the calendar to write a note. Dates with notes show a small dot; notes are saved automatically.



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
- Weather

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
systemctl --user enable --now tide-island.service
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

Search `Tide Island Settings` in any application launcher, or run:

```bash
tide-island-config-app
```

- **Shortcuts**: Configure shortcuts for Workspace Overview, Application Launcher, Music Player, Notification Center, Control Center, Clipboard History (`Super + V`), Weather (`Super + E`), and Calendar (`Super + K` by default).
- **Interaction**: Configure click actions for the dynamic island pill (Left, Middle, and Right mouse buttons for Player, Control Center, and Clipboard History).
- **Weather**: Configure auto-detection or custom city name, temperature units (°C or °F), and refresh interval.
- **Calendar**: Quick month view with week numbers and relative date indicators. Click the date in the Control Center, press `Super + K`, or use the scroll wheel / arrow keys to browse months. Press `Home` to return to today, and `Esc` to close.


## Spotify favorites

The expanded music player can add or remove the current Spotify track from Liked Songs and reflect changes made in the Spotify client.
It uses your local Spotify desktop client and [Spicetify](https://spicetify.app/docs/getting-started), without a Spotify developer application, API key, browser automation, or hosted server. There is no developer-application user allowlist, and saving tracks uses your signed-in account's normal library permissions without requiring Premium for this feature.

After installing/updating Tide Island, open Spotify and sign in, install Spicetify, and run this as your desktop user:

```bash
tide-island-spotify-setup
```

This installs the companion extension, automatically creating, reusing, or migrating the stock backup as needed. Spotify may restart.
From the source checkout, use `python3 scripts/spotify-setup.py`. Existing themes and other extensions are preserved.

Open the expanded player and use the heart on the right. A filled heart means the song is saved.
The button is unavailable while disconnected, while its state is unknown, or while an update is pending. Requests are bound to track URIs so a late reply cannot change the next song's displayed state.

The bridge listens only on `127.0.0.1`, using port `8976` by default. Its configuration is stored in `$XDG_CONFIG_HOME/tide-island/spotify-bridge.json` (normally `~/.config/tide-island/spotify-bridge.json`). The token authenticates the local bridge only; no Spotify password, cookie, or access token is sent to Tide Island.

```bash
# Choose another port if the default is occupied
tide-island-spotify-setup --port 9898

# Prepare the files without applying them yet
tide-island-spotify-setup --no-apply

# Remove the companion extension and bridge configuration
tide-island-spotify-setup --remove

# Inspect connection, track, and favorite state without account credentials
quickshell ipc call tide spotifyFavoritesStatus
```

If a Spotify update breaks favorites, update Spicetify and rerun setup. A compatible desktop client and Spicetify installation are required. Favorites currently support Spotify catalog tracks; local files, podcasts, and other MPRIS players do not show the heart.
Qt WebSockets is a new build/runtime dependency, included in the Arch package and source installer dependency lists.

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

You can control Tide Island remotely using `quickshell ipc call`:

| Command | Action |
| --- | --- |
| `quickshell ipc call tide toggleCalendar` | Open or close calendar view |
| `quickshell ipc call tide openCalendar` | Open calendar view |
| `quickshell ipc call tide closeCalendar` | Close calendar view |
| `quickshell ipc call tide toggleWeather` | Open or close weather view |
| `quickshell ipc call tide openWeather` | Open weather view |
| `quickshell ipc call tide closeWeather` | Close weather view |
| `quickshell ipc call weather refresh` | Refresh weather data immediately |
| `quickshell ipc call tide toggleClipboard` | Open or close clipboard history |
| `quickshell ipc call tide openClipboard` | Open clipboard history |
| `quickshell ipc call tide closeClipboard` | Close clipboard history |
| `quickshell ipc call tide toggleNotificationCenter` | Open or close notification center |
| `quickshell ipc call tide openNotificationCenter` | Open notification center |
| `quickshell ipc call tide closeNotificationCenter` | Close notification center |
| `quickshell ipc call tide toggleApplicationLauncher` | Open or close application launcher |

<br>

### Notification Centre

Click the × button on a notification card to dismiss it. Use **Clear All** to dismiss all notifications at once.

<br>

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

-  only 1 topic per issue.
-  tell your ideas first before making a PR

## Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the workspace overview design inspiration
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend
- [@LatifKovani](https://github.com/LatifKovani) for a significant improvement

## Community

- Discord:https://discord.gg/Rcj3uPtKwD
- Email: enhaoswen@gmail.com

## Star History

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
    Made for Wayland users who like quiet and practical desktops.
  </sub>
</p>
