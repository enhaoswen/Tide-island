# Dynamic-islalnd-on-hyprland
- Dynamic Island is a smooth, flexible, and fast interactive island component designed for Hyprland users.

- Based on Quickshell and C.

- Pursuting lightweight, smooth anim, and low-latency performance. (Talking about some latency)

## Description:

### usage:

Memory usage: 20-35Mb

CPU usage: 0.8% - 1.2%

#### style 1: normal - only show time

<div align="left">
  <img src="Preview/Preview_1.png" width="450" alt="Preview">
</div>

#### style 2: split - when brightness, volume, bluetooth, etc. changes

<div align="left">
  <img src="Preview/Preview_2.png" width="450" alt="Preview">
</div>

<div align="left">
  <img src="Preview/Preview_3.png" width="450" alt="Preview">
</div>

<div align="left">
  <img src="Preview/Preview_4.png" width="450" alt="Preview">
</div>

#### style 3: long-capsules - when workspace changes

<div align="left">
  <img src="Preview/Preview_5.png" width="450" alt="Preview">
</div>

#### style 4: expanded - when click/ song changes

<div align="left">
  <img src="Preview/Preview_6.png" width="450" alt="Preview">
</div>

### Dependencies:

- Quickshell

- socat

- pactl & pipewire

- JetBrainsMono Nerd Font (necessary)

### Compile & run:
```bash
git clone https://github.com/enhaoswen/Dynamic-Island-on-Hyprland.git
cd Dynamic-Island-on-Hyprland

gcc -O3 island_backend.c -o island_backend

mkdir -p ~/.config/quickshell
mv island_backend *.qml ~/.config/quickshell/

cd .. && rm -rf Dynamic-Island-on-Hyprland

quickshell
```
## Repeating important things three times

**Make sure island_backend is in .config/quickshell, or else pls change the path in shell.qml:134**

**Make sure island_backend is in .config/quickshell, or else pls change the path in shell.qml:134**

**Make sure island_backend is in .config/quickshell, or else pls change the path in shell.qml:134**
