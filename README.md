<h1 align="center">🌊 Tide Island</h1>

<p align="center">
  <b>A smooth, light and flexible Dynamic Island for Hyprland and niri.</b>
</p>

<p align="center">
  <img alt="Stars" src="https://img.shields.io/github/stars/enhaoswen/Tide-island?style=for-the-badge&logo=github">
  <img alt="AUR" src="https://img.shields.io/aur/version/tide-island?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-0.3%2B-5e81ac?style=for-the-badge">
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
  <a href="#-preview">Preview</a>
  ·
  <a href="#-features">Features</a>
  ·
  <a href="#-installation">Installation</a>
  ·
  <a href="#-configuration">Configuration</a>
  ·
  <a href="#-common-commands">Commands</a>
  ·
  <a href="#-faq">FAQ</a>
</p>

---

> [!WARNING]
> **Tide Island has moved to a new repository.**
>
> This version still works well and stays available here, but it is **no longer actively maintained**.
> A new version is under development, but it is **not finished yet**.
>
> For the latest news, please go to **[Tide Island — New Repository](https://github.com/enhaoswen/Tide-Island-New)**.

## ✨ About

Tide Island is a small desktop widget for Hyprland and niri. It looks like the Dynamic Island on iPhone.

Most of the time it just sits in the corner and stays out of your way. When you need something, it opens into a panel. You can check lyrics, switch workspaces, change system settings, read notifications, or show your own custom content.

It is built with Quickshell, QML, and C++/Qt 6. I spent most of the time on three things: smooth animations, fast response, and low resource usage. It is not perfect, but I hope it feels comfortable to use.

<br>

## 🎬 Preview

https://github.com/user-attachments/assets/bb3defb8-8af0-4a13-acde-3ed8ee8feef9

<br>

## 🧩 Features

| | Feature | | Feature |
| --- | --- | --- | --- |
| 🕒 | Clock | 🎵 | Music player |
| 🎛️ | Control Center | ⏱️ | Timer |
| 🎤 | Lyrics | 🚀 | Application launcher |
| 🗂️ | File shelf | 📋 | Clipboard history |
| 🌤️ | Weather & forecast | 📅 | Calendar (with notes) |
| 🖼️ | Wallpaper switcher | 🪟 | Workspace overview |
| 🎨 | Custom page | 🔔 | Notification center |
| ⏻ | Power menu | 🔒 | Lock screen |

**Some small notes:**

- **Clipboard history** needs `cliphist` and `wl-clipboard`. Tide Island starts the clipboard watcher for you while it is running.
- **Calendar:** click a date to write a note. Notes are saved automatically, and a date with a note shows a small dot.

### 📡 System feedback

The island shows a short hint when these things happen:

- Volume changes
- Brightness changes
- Battery charging / discharging
- Workspace changes
- Media playback (optional)
- System notifications

### 🎨 Custom page

You can put these items on your custom page:

| | | | |
| --- | --- | --- | --- |
| Time | Date | Battery | Volume |
| CPU usage | Memory usage | Storage usage | Brightness |
| Current workspace | Weather | Cava | |

### 🖥️ Compositor support

| Compositor | What you get |
| --- | --- |
| **Hyprland** | The full experience: Tide's own workspace overview, workspace animations, shortcuts, and Night Light through `hyprsunset`. |
| **niri** | Island views, focused-output IPC commands, workspace change hints, native niri overview, shortcuts through `~/.config/tide-island/niri-shortcuts.kdl`, and Night Light through `gammastep`. |

<br>

## 📦 Installation

### Arch Linux

Install from the AUR:

```bash
yay -S tide-island
```

### Other Linux distributions

Download the source package and the checksum from the
[latest GitHub Release](https://github.com/enhaoswen/Tide-island/releases/latest), then install:

```bash
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/tide-island-source.tar.xz
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xf tide-island-source.tar.xz
cd Tide-island-*
./install.sh
```

The installer puts Tide Island in `/usr`. It can install dependencies for you on:

- Debian, Ubuntu and derivatives (`apt`)
- Fedora, RHEL and derivatives (`dnf`)
- openSUSE (`zypper`)

On other distributions, please install the dependencies yourself first, then run:

```bash
./install.sh --skip-deps
```

> [!NOTE]
> This installer is made for normal Linux systems where `/usr` is writable.
> On declarative or immutable systems (for example NixOS or Fedora Silverblue), please use a native package or a mutable development container instead.

<details>
<summary><b>Installer options</b></summary>

<br>

| Option | What it does |
| --- | --- |
| `./install.sh --no-service` | Install Tide Island, but do not enable or start the systemd user service. |
| `./install.sh --skip-quickshell` | Do not build Quickshell from source. Use the existing `/usr/bin/quickshell` instead. The installer stops with an error if this file does not exist. |
| `./install.sh --force-build-quickshell` | Rebuild and install the pinned Quickshell version of this project, even if Quickshell is already installed. |
| `./install.sh --uninstall` | Remove the files installed by the source installer. Dependencies and Quickshell are kept. |

</details>

<br>

## 🚀 Starting Tide Island

Tide Island comes with a systemd user service. This is the recommended way:

```bash
systemctl --user enable --now tide-island.service
```

If you prefer to start it by yourself, add one line to your Hyprland config.

`hyprland.conf`:

```conf
exec-once = tide-island
```

`hyprland.lua`:

```lua
hl.exec_once("tide-island")
```

> [!TIP]
> If the systemd service is already enabled, you do **not** need `exec-once`. Using both will start it twice.

<br>

## ⚙️ Configuration

Search for `Tide Island Settings` in your application launcher, or run:

```bash
tide-island-config-app
```

### 🔒 Lock screen

With Tide Island running, there are two ways to lock the screen:

- Open **Settings → Lock screen** and click **Lock now**.
- Click the lock button in the power menu of the Control Center.

You can also use a shortcut. Apply **Lock screen** on the **Shortcut** page (default: `Super + L`).

**About background blur**

The blur uses Quickshell 0.3+
[BackgroundEffect](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/BackgroundEffect/),
so your compositor needs to support `ext-background-effect-v1`.
The rounded blur regions follow the visible panels during transitions, and they disappear when the panels close.
If your compositor does not support this protocol, you still see the tinted surfaces, just without blur.
The layer-shell namespace is `tide-island`.

The blur regions sit inside the antialiased surface, with a thin and light outline.

<details>
<summary><b>Hyprland: blur looks wrong during resize?</b></summary>

<br>

Tide animates its own panels. Hyprland's layer animation can scale the whole surface on top of that. This stretches the text and moves the blur out of place while resizing.

If you use a Lua config, turn off this extra animation only for Tide:

```lua
hl.layer_rule({
    name = "tide-island-native-morph",
    match = { namespace = "^tide-island$" },
    no_anim = true,
})
```

</details>

### 💚 Spotify favorites

In the expanded music player, you can add or remove the current Spotify track from **Liked Songs**. Changes you make in the Spotify client show up in the player too.

How it works: it talks to your local Spotify desktop client through [Spicetify](https://spicetify.app/docs/getting-started). That means:

- No Spotify developer application, API key, browser automation or hosted server.
- No developer-application user allowlist.
- It uses the normal library permission of your signed-in account. Premium is not required for this feature.

**Setup**

1. Install or update Tide Island.
2. Open Spotify and sign in.
3. Install Spicetify.
4. Run this as your desktop user:

```bash
tide-island-spotify-setup
```

This installs the companion extension. It creates, reuses or migrates the stock backup automatically when needed. Spotify may restart. Your themes and other extensions are kept.
If you run from the source checkout, use `python3 scripts/spotify-setup.py` instead.

**Use it**

Open the expanded player and click the heart on the right. A filled heart means the song is saved.

The heart button is not available when:

- Spotify is disconnected,
- the state of the song is unknown, or
- an update is still pending.

Every request is tied to a track URI, so a late reply can never change the heart of the next song.

**Safety and config**

- The bridge listens only on `127.0.0.1`. The default port is `8976`.
- The config is saved in `$XDG_CONFIG_HOME/tide-island/spotify-bridge.json` (normally `~/.config/tide-island/spotify-bridge.json`).
- The token only authenticates the local bridge. No Spotify password, cookie or access token is sent to Tide Island.

```bash
# Use another port if the default one is busy
tide-island-spotify-setup --port 9898

# Prepare the files, but do not apply them yet
tide-island-spotify-setup --no-apply

# Remove the companion extension and the bridge config
tide-island-spotify-setup --remove

# Check connection, track and favorite state (no account credentials needed)
quickshell ipc call tide spotifyFavoritesStatus
```

**Limits**

- Only Spotify catalog tracks are supported. Local files, podcasts and other MPRIS players do not show the heart.
- If a Spotify update breaks favorites, update Spicetify and run the setup again. You need a compatible Spotify desktop client and Spicetify.
- Qt WebSockets is a new build/runtime dependency. It is already included in the Arch package and in the source installer dependency lists.

<br>

## 🛠️ Common Commands

**Restart after editing the configuration**

```bash
systemctl --user restart tide-island
```

**Stop Tide Island**

```bash
systemctl --user stop tide-island
```

**Watch the logs**

```bash
journalctl --user -u tide-island -f
```

### 📡 IPC commands

You can control Tide Island from the terminal, a keybind or a script with `quickshell ipc call`.

| View | Toggle | Open | Close |
| --- | --- | --- | --- |
| Calendar | `quickshell ipc call tide toggleCalendar` | `quickshell ipc call tide openCalendar` | `quickshell ipc call tide closeCalendar` |
| Weather | `quickshell ipc call tide toggleWeather` | `quickshell ipc call tide openWeather` | `quickshell ipc call tide closeWeather` |
| Clipboard history | `quickshell ipc call tide toggleClipboard` | `quickshell ipc call tide openClipboard` | `quickshell ipc call tide closeClipboard` |
| Notification center | `quickshell ipc call tide toggleNotificationCenter` | `quickshell ipc call tide openNotificationCenter` | `quickshell ipc call tide closeNotificationCenter` |
| Application launcher | `quickshell ipc call tide toggleApplicationLauncher` | — | — |

Other commands:

| Command | Action |
| --- | --- |
| `quickshell ipc call weather refresh` | Refresh the weather data right now |
| `quickshell ipc call tide spotifyFavoritesStatus` | Show the Spotify favorites status |

<details>
<summary><b>Keybind example (Hyprland)</b></summary>

<br>

```conf
bind = SUPER, C, exec, quickshell ipc call tide toggleCalendar
bind = SUPER, V, exec, quickshell ipc call tide toggleClipboard
bind = SUPER, N, exec, quickshell ipc call tide toggleNotificationCenter
bind = SUPER, SPACE, exec, quickshell ipc call tide toggleApplicationLauncher
```

Change the keys to anything you like.

</details>

<br>

## ❓ FAQ

<details>
<summary><b>The island does not show up.</b></summary>

<br>

Check if the service is running, then read the logs:

```bash
systemctl --user status tide-island
journalctl --user -u tide-island -f
```

Also make sure you are not starting it twice (systemd service **and** `exec-once`).

</details>

<details>
<summary><b>Clipboard history is empty.</b></summary>

<br>

Please check that `cliphist` and `wl-clipboard` are installed.

</details>

<details>
<summary><b>There is no blur.</b></summary>

<br>

Your compositor probably does not support `ext-background-effect-v1`. Tide Island will show the tinted surfaces without blur. This is normal.

</details>

<details>
<summary><b>Night Light does not work.</b></summary>

<br>

On Hyprland it needs `hyprsunset`. On niri it needs `gammastep`.

</details>

<br>

## 🤝 Contributing

Issues, bug reports, design ideas and pull requests are all welcome.

- Please open **one topic per issue**.
- Please **tell your idea first** before you make a PR.

## 💐 Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the inspiration of the workspace overview design
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend
- [@LatifKovani](https://github.com/LatifKovani) for a big improvement

## 💬 Community

- Discord: <https://discord.gg/Rcj3uPtKwD>
- Email: <enhaoswen@gmail.com>

## ⭐ Star History

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
    Made for Wayland users who like quiet and practical desktops. 🌊
  </sub>
</p>
