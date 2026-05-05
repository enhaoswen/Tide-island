# Tide Island
- Tide Island is a smooth, flexible, and fast interactive island component designed for Hyprland users.

- Based on Quickshell and C++ /Qt 6.

- Pursuting lightweight, smooth anim, and low-latency performance.

- **⚠️ To ensure you don't encounter unnecessary problems, read Important things and dependcies**
### usage

Memory usage: < 200 Mb (PSS)

CPU usage < 2%

## Description


Video: https://www.youtube.com/watch?v=vCA8sWLJjiw&list=LL&index=2


#### Clock Mode
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_1.png" width="450" alt="Preview"> </div>

#### System Notifications
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_2.png" width="450" alt="Preview"> </div>

#### Workspace Indicator
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_5.png" width="450" alt="Preview"> </div>

#### Lyrics
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_6.png" width="450" alt="Preview"> </div>

#### Control Center
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_3.png" width="450" alt="Preview"> </div> 
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_8.png" width="450" alt="Preview"> </div>

#### Music Player
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_4.png" width="450" alt="Preview"> </div>

#### Workspace Overview
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_7.png" width="450" alt="Preview"> </div>

#### Custom Page
<div align="left"> <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/Preview_9.png" width="450" alt="Preview"> </div>

### Items that are supported in Custom Page
- time
- data
- battery
- volume
- brightness
- workspace
- cpu
- ram
- cava

### Control

| Action | Behavior |
|--------|----------|
| Left Click | Open Music Player |
| Right Click | Open Control Center |
| Swipe Left | Show Lyrics |
| Swipe Right | Custom Page |
| Super + Tab | Open Workspace Overview |
| Charging / Discharging | Display battery status icon |
| Brightness Change | Show brightness OSD |
| Volume Change | Show volume OSD |
| Caps Lock Toggle | Show status message |


## Dependencies

### Core Runtime Dependencies

- This project is consumed directly by Quickshell at runtime and does not require a local build step.
- Hyprland
- Quickshell
- `hyprctl`
- `wpctl`
- `brightnessctl`
- `dbus-monitor`
- `pactl`
- UPower DBus service
- Access to `/sys/class/power_supply`
- `libudev`
- BlueZ DBus service
- Wi-Fi backend supported by the bundled connectivity plugin:
  - NetworkManager, or
  - iwd

### Optional Runtime Dependencies

- `cava`
  - Required only if you enable the `cava` left-swipe module.
- ImageMagick (`magick` or `convert`)
  - Used only for workspace overview wallpaper thumbnail caching.
- `lyricsmpris`
  - External helper used for lyrics integration.
- `playerctld`
  - Improves MPRIS player discovery for lyrics/media integration.

#### Assets & Scripts

- Any nerd font (for icon) && any font (for text) 

## Installation

### Arch Linux (Recommended)
The easiest way to install Tide Island is via the AUR or by building the provided PKGBUILD.

**Using an AUR Helper:**
```bash
yay -S tide-island-git
```

**Manual Installation:**
```bash
git clone https://github.com/sai21-learn/Tide-island.git
cd Tide-island
makepkg -si
```

### Starting the Island
Tide Island includes a systemd user service for automatic startup and background management.

**Enable and start the service:**
```bash
systemctl --user enable --now tide-island
```

**Manage the service:**
```bash
# Restart the island (e.g. after config changes)
systemctl --user restart tide-island

# Stop the island
systemctl --user stop tide-island

# View logs
journalctl --user -u tide-island -f
```

### Manual Usage
If you prefer to run it manually:
```bash
tide-island
```

## Configuration
The default configuration is located at `/usr/share/tide-island/UserConfig.qml`.

## Acknowledgments

- [@end-4](https://github.com/end-4) - For the workspace overview design.
- [@BEST8OY](https://github.com/BEST8OY) - For providing the lyrics support.
- [@gozhuimeng](https://github.com/gozhuimeng) - For improve the lyrics backend.

## Important things

- **The backend is hardcoded to read /sys/class/backlight/intel_backlight/. If you are using AMD or a different backlight driver, please update the path (SysBackend.cpp:353).**

- **The status of caps lock is currently polled via hyprctl devices. Ensure hyprctl is in your $PATH.**

- **If you encounter any issues, feel free to open an issue!**

-  **Please write your password in UserConfig.qml line 16, to make sure tlp switcher works normally**

## Join the community
- Discord: https://discord.gg/gEmqgz76

- Gmail: whysoorak.official@gmail.com
