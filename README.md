# ❄️ NyxOS: Framework 13 (AI 300) Niri Configuration

A declarative, modular, and opinionated **NixOS 25.11** configuration designed specifically for the **Framework 13 AMD (AI 300 / Strix Point)**.

This flake features a unique **"Desktop Router"** system that allows instant switching between a modern **Noctalia** desktop and a retro-futuristic **Waybar (Aurora)** setup, while sharing a unified shell, keybinding, and theming backend.

## 🏗 Architecture

*   **Basis:** NixOS 25.11 + Home Manager (Flakes).
*   **Compositor:** [Niri](https://github.com/YaLTeR/niri) (Scrollable Tiling Wayland Compositor).
*   **Theme:** Catppuccin Mocha (managed via **Stylix**).
*   **Shells:** Fish (Primary) & Bash (Fallback) with unified aliases.
*   **Kernel:** `linuxPackages_latest` (Required for RDNA 3.5 graphics & NPU support).

---

## 🌗 The Dual-Profile System

This configuration features two distinct desktop personalities toggleable via `home-ashy.nix`.

| Feature | **Noctalia Profile** | **Waybar Profile** |
| :--- | :--- | :--- |
| **Aesthetic** | Modern, Material You, Widget-heavy | Cyberpunk/Aurora, Transparent, Text-heavy |
| **Bar** | Noctalia Shell (Quickshell) | Waybar (Aurora Config) |
| **Launcher** | Fuzzel | Wofi |
| **Terminal** | Kitty | Kitty |
| **Notification** | Mako | Mako |

### How to Switch
Edit `home-ashy.nix`:
```nix
my.desktop.panel = "noctalia";  # or "waybar"
```
Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#nyx
```

---

## 🛠️ Features & Tooling

### 🖱️ Hardware & Input
*   **G502 Lightspeed:** Custom CLI tool (`g502-manager`) to map hardware buttons to system actions without GUI bloat.
*   **DualSense:** Kernel-level support with `game-devices-udev-rules`.
*   **Bluetooth:** Custom minimalist BlueZ build (stripped of OBEX/Mesh bloat).

### ⚡ Performance
*   **ZRAM:** Hot-swappable modules in `flake.nix` (LZ4 for speed vs ZSTD for capacity).
*   **Sysctl:** Tuned `vm.dirty_ratio` for responsiveness under load.

### 🤖 AI & Development
*   **Local AI:** `aichat`, `rocm-smi`, `python` data science stack.
*   **Web Apps:** Isolated, sandboxed Brave instances for Discord, AI Studio, etc. (Wayland native).
*   **Chat Swapper:** Custom `aiswap` tool to toggle AI models/personas instantly.

---

## ⚙️ Installation & Configuration

### 1. Default User
*   **Username:** `ashy`
*   **Default Password:** `icecream`

### 2. Changing the Password
After installation, change the password immediately:
```bash
passwd
```
To set a permanent declarative hash, generate one with `mkpasswd -m sha-512` and update `users.users.ashy.hashedPassword` in `configuration.nix`.

### 3. MAC Address Spoofing
This config hardcodes a MAC address for privacy.
**Edit `configuration.nix`:**
```nix
# Ensure 'enp1s0' matches your actual interface name (check with `ip link`)
networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";
```

### 4. Custom Scripts
These are available system-wide in your terminal AND bindings:
*   `g502-manager`: Manage mouse profiles.
*   `aichat-swap`: Switch AI personalities.
*   `waybar-cycle-wall`: Cycle wallpapers (Waybar profile).
*   `extract`: A universal archive extractor.

---

## ⌨️ Keybindings (Niri)

The bindings are normalized so muscle memory works regardless of which profile is active.

| Keybind | Action | Description |
| :--- | :--- | :--- |
| `Super + Return` | Terminal | Opens Kitty |
| `Super + A` | Launcher | Fuzzel (Noctalia) OR Wofi (Waybar) |
| `Super + Q` | Close | Close active window |
| `Super + W` | Wallpaper | Toggle Wallpaper/Cycler |
| `Super + P` | Power | Session Menu (Noctalia) or Wofi Power (Waybar) |
| `Super + V` | Clipboard | Clipboard History Manager |
| `Super + Scroll` | Scroll | Scroll the Niri timeline |
| `F23 / F24` | Mouse | G502 Specific Profile Switching |
| `Print` | Screenshot | Fullscreen Screenshot |

---

## 📦 Core Package List

**System & Utils**
`git`, `curl`, `wget`, `micro`, `unzip`, `unrar`, `p7zip`, `libnotify`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `udiskie`, `socat`.

**Audio & Video**
`pipewire`, `wireplumber`, `pwvucontrol`, `playerctl`, `ffmpeg`, `mpv`, `gstreamer` (full plugins).

**Terminal**
`kitty`, `alacritty`, `eza` (ls), `bat` (cat), `fzf`, `zoxide`, `starship`, `ripgrep`, `jq`, `fastfetch`, `macchina`, `btop`.

**Gaming**
`steam` (via program), `mangohud`, `latencyflex-vulkan`, `libratbag`.

**AI & Data**
`python3` (numpy, pandas), `rocmPackages`, `aichat`.

---

## 🎨 Credits

*   **Aurora Theme:** The Waybar configuration, styling, and visual aesthetic are heavily based on the beautiful [Aurora Dotfiles by flickowoa](https://github.com/flickowoa/dotfiles/tree/aurora). The `config` and `style.css` have been ported to Nix and adapted for Niri workspaces.
*   **Catppuccin:** System-wide coloring provided by [Catppuccin](https://github.com/catppuccin/catppuccin).
*   **Niri:** The infinite scrolling compositor logic is by [YaLTeR](https://github.com/YaLTeR/niri).
