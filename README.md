# ❄️ NyxOS (NixOS 25.11) — Framework 13 AMD (AI 300 / Strix Point) + Niri

A declarative, modular, opinionated **NixOS 25.11** flake for the **Framework 13 AMD (AI 300 / Strix Point)**.

The standout feature is a **Desktop Router**: switch between a modern **Noctalia** desktop and a retro-futuristic **Waybar (Aurora)** setup while keeping a unified shell, keybinding, and theming backend.

---

## Table of contents

- [Architecture](#-architecture)
- [Dual-profile system](#-the-dual-profile-system)
- [Features & tooling](#️-features--tooling)
- [Installation & configuration](#️-installation--configuration)
- [Keybindings (Niri)](#-keybindings-niri)
- [Core package list](#-core-package-list)
- [Performance optimizations](#-performance-optimizations)
- [Credits](#-credits)

---

## 🏗 Architecture

- **Basis:** NixOS 25.11 + Home Manager (flakes)
- **Compositor:** [Niri](https://github.com/YaLTeR/niri) — scrollable tiling Wayland compositor
- **Theme:** Catppuccin Mocha (via **Stylix**)
- **Shells:** Fish (primary) + Bash (fallback) with unified aliases
- **Kernel:** `linuxPackages_latest` (RDNA 3.5 graphics & NPU support)

---

## 🌗 The dual-profile system

Two desktop personalities, toggleable via `home-ashy.nix`:

| Feature | **Noctalia** | **Waybar (Aurora)** |
| --- | --- | --- |
| Aesthetic | Modern, Material You, widget-heavy | Cyberpunk/Aurora, transparent, text-heavy |
| Bar | Noctalia Shell (Quickshell) | Waybar (Aurora config) |
| Launcher | Fuzzel | Wofi |
| Terminal | Kitty | Kitty |
| Notifications | Mako | Mako |

### Switch profiles

Edit `home-ashy.nix`:

```nix
my.desktop.panel = "noctalia";  # or "waybar"
````

Rebuild:

```bash
sudo nixos-rebuild switch --flake .#nyx
```

---

## 🛠️ Features & tooling

### 🖱️ Hardware & input

* **G502 Lightspeed:** `g502-manager` CLI for hardware profile mapping (no GUI bloat)
* **DualSense:** kernel-level support via `game-devices-udev-rules`
* **Bluetooth:** custom minimal BlueZ build (stripped of OBEX/Mesh extras)

### ⚡ Performance

* **ZRAM:** hot-swappable modules in `flake.nix` (LZ4 for speed vs ZSTD for capacity)
* **Sysctl:** tuned `vm.dirty_ratio` for better responsiveness under load

### 🤖 AI & development

* **Local AI:** `aichat`, `rocm-smi`, Python data stack
* **Web apps:** isolated/sandboxed Brave instances for Discord, AI Studio, etc (Wayland-native)
* **Chat swapper:** `aiswap` for quickly switching AI profiles

---

## ⚙️ Installation & configuration

### Default user

* **Username:** `ashy`
* **Default password:** `icecream`

### Change password

Change immediately after install:

```bash
passwd
```

To set a **declarative** password hash:

1. Generate a hash: `mkpasswd -m sha-512`
2. Set `users.users.ashy.hashedPassword` in `configuration.nix`

### MAC address spoofing

This config hardcodes a MAC for privacy. Edit `configuration.nix`:

```nix
# Ensure 'enp1s0' matches your real interface name (`ip link`)
networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";
```

### Custom scripts

Available system-wide (terminal + bindings):

* `g502-manager` — manage mouse profiles
* `aichat-swap` — switch AI personalities
* `waybar-cycle-wall` — wallpaper cycling (Waybar profile)
* `extract` — universal archive extractor

---

## ⌨️ Keybindings (Niri)

Bindings are normalized so muscle memory stays consistent across both profiles.

| Keybind          | Action     | Description                                   |
| ---------------- | ---------- | --------------------------------------------- |
| `Super + Return` | Terminal   | Opens Kitty                                   |
| `Super + A`      | Launcher   | Fuzzel (Noctalia) / Wofi (Waybar)             |
| `Super + Q`      | Close      | Close active window                           |
| `Super + W`      | Wallpaper  | Toggle wallpaper / cycler                     |
| `Super + P`      | Power      | Session menu (Noctalia) / Wofi power (Waybar) |
| `Super + V`      | Clipboard  | Clipboard history manager                     |
| `Super + Scroll` | Scroll     | Scroll the Niri timeline                      |
| `F23 / F24`      | Mouse      | G502 profile switching                        |
| `Print`          | Screenshot | Fullscreen screenshot                         |

---

## 📦 Core package list

### System & utils

`git`, `curl`, `wget`, `micro`, `unzip`, `unrar`, `p7zip`, `libnotify`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `udiskie`

### Audio & video

`pipewire`, `wireplumber`, `pwvucontrol`, `playerctl`, `ffmpeg`, `mpv`, `gstreamer` (full plugin set)

### Terminal & CLI

`kitty`, `alacritty`, `eza`, `bat`, `fzf`, `zoxide`, `starship`, `ripgrep`, `jq`, `fastfetch`, `macchina`, `btop`

### Gaming

`mangohud`, `latencyflex-vulkan`, `libratbag`

### AI & data

`python3` (numpy, pandas), `rocmPackages`, `aichat`

---

## ⚡ Performance optimizations

This configuration includes optimizations across boot, memory, filesystem, networking, services, monitoring, and advanced tuning.

> Tip: If you want this section shorter in the README, the natural split is:
>
> * `docs/performance.md` (full guide)
> * README keeps the summary + common commands

### Quick validation

```bash
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain
cat /proc/cmdline
```

<details>
<summary><strong>Phase 1 — System-wide optimizations</strong></summary>

#### Boot & kernel

* Parallel startup, reduced timeouts
* Kernel params: `nowatchdog`, `nmi_watchdog=0`, `tsc=reliable`

#### Memory management

* `vm.swappiness=10`
* `vm.vfs_cache_pressure=50`
* Tuned dirty writeback settings

Validation:

```bash
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure
free -h
vmstat 1
```

#### Filesystem (Btrfs)

* Mount options: `noatime,nodiratime,compress=zstd,space_cache=v2,ssd,commit=120`
* Maintenance: weekly scrub, monthly balance, daily TRIM
* Transparent Zstd compression

Validation:

```bash
mount | grep btrfs
btrfs filesystem usage /
btrfs filesystem df /
```

#### Network stack

* Increased socket limits, tuned TCP buffers, connection reuse

Validation:

```bash
sysctl net.ipv4.tcp_tw_reuse
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_rmem
```

</details>

<details>
<summary><strong>Phase 2 — Service-specific optimizations</strong></summary>

#### Display manager (SDDM)

```bash
sudo systemctl restart sddm
systemctl status sddm
journalctl -u sddm -b
```

#### Audio (PipeWire)

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
pw-top
wpctl status
```

#### Power management

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
powerprofilesctl list
powerprofilesctl set performance
```

#### Network services

```bash
sudo systemctl restart NetworkManager
nmcli general status
ip addr show
```

</details>

<details>
<summary><strong>Monitoring & visualization</strong></summary>

#### Netdata

* Dashboard: `http://localhost:19999`

```bash
sudo systemctl status netdata
journalctl -u netdata -f
```

#### Prometheus Node Exporter

* Metrics: `http://localhost:9100/metrics`

```bash
sudo systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | grep btrfs
```

#### Grafana (optional)

* Dashboard: `http://localhost:3000` (when enabled)

```bash
sudo systemctl status grafana-server
sudo systemctl restart grafana-server
journalctl -u grafana-server -f
```

</details>

<details>
<summary><strong>Phase 3 — Advanced tuning</strong></summary>

#### HugePages + overcommit

```bash
cat /proc/meminfo | grep Huge
sysctl vm.nr_hugepages
sysctl vm.overcommit_memory
sysctl vm.overcommit_ratio
```

#### Btrfs advanced options

* `zstd:3`, `autodefrag`, `thread_pool=4`

```bash
mount | grep btrfs
btrfs filesystem usage /
sudo btrfs filesystem defrag -r -v /
```

#### Network + I/O

* TCP BBR congestion control
* BFQ I/O scheduler

```bash
sysctl net.ipv4.tcp_congestion_control
cat /sys/block/nvme0n1/queue/scheduler
```

#### Scheduler tuning

```bash
sysctl kernel.sched_min_granularity_ns
sysctl kernel.sched_latency_ns
lscpu
```

</details>

### Optimization summary

| Phase | Area            | Impact (expected)                        |
| ----- | --------------- | ---------------------------------------- |
| 1     | Boot            | 20–40% faster boot                       |
| 1     | Memory          | 10–20% better memory behavior            |
| 1     | Filesystem      | better I/O + reduced disk usage          |
| 1     | Network         | better throughput + lower latency        |
| 2     | Services        | 15–30% better service performance        |
| 2     | Monitoring      | better system visibility                   |
| 3     | Advanced tuning | incremental gains for specific workloads |

---

## 🎨 Credits

* **Aurora Theme:** Waybar styling based on [Aurora Dotfiles by flickowoa](https://github.com/flickowoa/dotfiles/tree/aurora), ported/adapted to Nix + Niri workspaces
* **Catppuccin:** system coloring by [Catppuccin](https://github.com/catppuccin/catppuccin)
* **Niri:** compositor by [YaLTeR](https://github.com/YaLTeR/niri)
